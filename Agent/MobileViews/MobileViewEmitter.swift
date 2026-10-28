//
//  MobileViewEmitter.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

@_implementationOnly import NewRelicPrivate
import Foundation

// MARK: - Schema

/// Every attribute name the MobileView / MobileViewTiming schemas use, defined once.
///
/// These used to live as `static NSString * const` blocks duplicated across
/// NRMAViewContext.m, NRMAViewTiming.m and NRMAMobileViewTracker.m, with the SwiftUI
/// producers using bare literals instead.
internal enum NRViewAttribute {
    static let viewClass              = "viewClass"
    static let viewName               = "viewName"
    static let viewInstanceId         = "viewInstanceId"
    static let previousView           = "previousView"
    static let previousViewInstanceId = "previousViewInstanceId"
    static let uiFramework            = "uiFramework"
    static let loadTime               = "loadTime"
    static let loadTimeUnavailable    = "loadTimeUnavailable"
    static let timeVisible            = "timeVisible"
    static let containsWebView        = "containsWebView"
    static let isFullScreenWebView    = "isFullScreenWebView"
    static let isTopLevelView         = "isTopLevelView"
    static let timingName             = "timingName"
    static let timingValue            = "timingValue"

    /// The MobileView schema (IDD §5.3). Customer-supplied attributes can never set these, whether
    /// or not a given event writes the key itself.
    static let reservedForMobileView: Set<String> = [
        viewClass, viewName, viewInstanceId, previousView, previousViewInstanceId,
        uiFramework, loadTime, loadTimeUnavailable, timeVisible,
        containsWebView, isFullScreenWebView, isTopLevelView,
    ]
}

/// The UI toolkit that observed the view. Absent when a producer genuinely does not know,
/// which is why the record holds this as an optional rather than defaulting it.
///
/// Also what picks the gating flag, so a manual view stays `.manual` whatever toolkit its
/// caller declared -- that declaration is `MobileViewRecord.declaredFramework`.
internal enum NRViewFramework: String {
    case uiKit   = "UIKit"
    case swiftUI = "SwiftUI"
    case manual  = "Manual"
}

/// Whether a view's construction-to-visible interval could be trusted.
///
/// The point of modelling this as a sum type is that `loadTime` and `loadTimeUnavailable`
/// are mutually exclusive and exactly one must be written. Every producer used to enforce
/// that with its own if/else chain, and they did not agree.
internal enum NRViewLoadOutcome {
    case measured(Double)                 // milliseconds
    case unavailable(Reason)

    internal enum Reason: String {
        /// setCurrentView without beginLoad
        case noLoadStartDeclared
        /// No construction start was observed for this visit, or it was more than
        /// kNRMAViewTimingMaxMilliseconds before the view appeared.
        case noConstructionObserved
        /// SwiftUI preserved this view's identity, so nothing was rebuilt and there is
        /// nothing to time.
        case notRebuilt
    }
}

/// Where `previousView` / `previousViewInstanceId` come from.
internal enum NRViewReferrer {
    /// No referrer on this event.
    case none
    /// Read the current referrer out of the shared view context.
    case fromContext
    /// The producer knows the referrer itself. Every producer captures the referrer when the
    /// view *appears* and hands it over here, because by emit time -- the end of the visit --
    /// the context has already moved on to whatever came next.
    case explicit(name: String?, instanceId: String?)
}

/// What the agent saw of one visit's view tree.
///
/// Every automatic producer supplies one, so its three attributes are always present on those events
/// and `WHERE containsWebView IS false` matches every native screen rather than missing the ones that
/// left the attribute out. A manual view has none: the agent never sees the customer's screen, and
/// writing `false` would claim it had looked.
internal struct NRViewComposition {
    /// A visible web view was in the tree at some point during the visit.
    var containsWebView: Bool
    /// One web view covered the content area (NRMAWebViewPresence) at some point during the visit.
    var isFullScreenWebView: Bool
    /// A screen in its own right rather than a child embedded in another tracked screen.
    var isTopLevelView: Bool
}

// MARK: - Records

/// One MobileView event, as facts rather than as a dictionary.
///
/// One event per visit, emitted when the view goes away: a visit is only fully describable
/// once it has ended, since `timeVisible` is not knowable before then. Producers used to emit
/// a second event on appear as well, which doubled the MobileView volume to carry `loadTime`
/// and the referrer -- both of which are captured at appear time and held by the producer
/// until this event is built.
///
/// The producer owns *when* things happened -- it holds the timestamps, the associated
/// objects and the locks. This type owns *what the event looks like*.
internal struct MobileViewRecord {
    var viewName: String
    var viewClass: String?
    var instanceId: String
    var framework: NRViewFramework?
    /// The toolkit a manual view's caller passed to setCurrentView: ("ReactNative", "Flutter",
    /// ...), written as `uiFramework` in place of "Manual". Ignored unless `framework` is
    /// `.manual`.
    var declaredFramework: String?
    var referrer: NRViewReferrer = .none
    /// Measured at appear time and carried until the visit ends. `nil` omits both loadTime
    /// and loadTimeUnavailable.
    var load: NRViewLoadOutcome?
    /// Milliseconds the view was on screen.
    var timeVisibleMs: Double?
    /// `nil` omits containsWebView, isFullScreenWebView and isTopLevelView.
    var composition: NRViewComposition?
    var custom: [String: Any]?

    /// Reserved keys are dropped from customer-supplied attributes, so the schema is stable no
    /// matter what an app returns from `nrMobileViewAttributes` or passes to setCurrentView:.
    internal func attributes() -> [String: Any] {
        var attrs: [String: Any] = (custom ?? [:]).filter {
            !NRViewAttribute.reservedForMobileView.contains($0.key)
        }

        switch referrer {
        case .none:
            break
        case .fromContext:
            let previous = NRMAViewContext.sharedInstance().previousViewAttributes()
            attrs.merge(previous) { _, new in new }
        case .explicit(let name, let instanceId):
            if let name = name, !name.isEmpty {
                attrs[NRViewAttribute.previousView] = name
            }
            if let instanceId = instanceId, !instanceId.isEmpty {
                attrs[NRViewAttribute.previousViewInstanceId] = instanceId
            }
        }

        attrs[NRViewAttribute.viewName]       = viewName
        attrs[NRViewAttribute.viewInstanceId] = instanceId

        if let viewClass = viewClass, !viewClass.isEmpty {
            attrs[NRViewAttribute.viewClass] = viewClass
        }
        // Omitted rather than defaulted: an absent uiFramework must read as absent, so a
        // producer that genuinely does not know which toolkit it saw cannot be mistaken for
        // one that reported an empty string.
        if let framework = framework {
            if framework == .manual, let declared = declaredFramework, !declared.isEmpty {
                attrs[NRViewAttribute.uiFramework] = declared
            } else {
                attrs[NRViewAttribute.uiFramework] = framework.rawValue
            }
        }

        // loadTime and loadTimeUnavailable are mutually exclusive by construction. loadTime
        // is omitted rather than zeroed when it cannot be trusted, so a placeholder does not
        // drag load-time percentiles toward zero; the reason is recorded so the omission is
        // diagnosable in NRDB rather than looking unimplemented.
        switch load {
        case .none:
            break
        case .some(.measured(let ms)) where ms <= kNRMAViewTimingMaxMilliseconds:
            attrs[NRViewAttribute.loadTime] = NSNumber(value: ms)
        case .some(.measured):
            // The construction start was not vouched for (NRMAViewContext), so this visit has no
            // baseline timing; loadTime must not report the interval the baseline refused.
            attrs[NRViewAttribute.loadTimeUnavailable] =
                NRViewLoadOutcome.Reason.noConstructionObserved.rawValue
        case .some(.unavailable(let reason)):
            attrs[NRViewAttribute.loadTimeUnavailable] = reason.rawValue
        }

        // Reported verbatim however short it is. A minimum-dwell threshold used to label
        // brief visits `churn` so screen-view counts could exclude them; that classification
        // is gone, and consumers that want to filter brief visits do it from `timeVisible`
        // itself rather than from a decision the agent baked in.
        if let timeVisibleMs = timeVisibleMs {
            attrs[NRViewAttribute.timeVisible] = NSNumber(value: timeVisibleMs)
        }

        if let composition = composition {
            // A full-screen web view is a web view: enforced here rather than trusted from each
            // producer, so no event can say the screen is a web page that contains no web view.
            let isFullScreen = composition.isFullScreenWebView
            attrs[NRViewAttribute.containsWebView] = NSNumber(value: composition.containsWebView || isFullScreen)
            attrs[NRViewAttribute.isFullScreenWebView] = NSNumber(value: isFullScreen)
            attrs[NRViewAttribute.isTopLevelView] = NSNumber(value: composition.isTopLevelView)
        }

        return attrs
    }

    @discardableResult
    internal func emit() -> Bool {
        guard NRMobileViewEmitter.isEnabled(for: framework) else { return false }
        return NRMobileViewEmitter.send(attributes(), timing: false)
    }
}

/// One MobileViewTiming event. A different event type, so a separate record: `viewName`
/// and `viewInstanceId` mean the same thing, but `timingName` / `timingValue` are this
/// schema's own and the two are free to diverge.
internal struct ViewTimingRecord {
    var timingName: String
    var timingValueMs: Double
    var viewName: String?
    var viewInstanceId: String?
    var previousView: String?

    internal func attributes() -> [String: Any] {
        var attrs: [String: Any] = [
            NRViewAttribute.timingName:  timingName,
            NRViewAttribute.timingValue: NSNumber(value: timingValueMs),
        ]
        // Only keys with values are set; an absent view must read as absent, not as an
        // empty string.
        if let viewName = viewName, !viewName.isEmpty {
            attrs[NRViewAttribute.viewName] = viewName
        }
        if let viewInstanceId = viewInstanceId, !viewInstanceId.isEmpty {
            attrs[NRViewAttribute.viewInstanceId] = viewInstanceId
        }
        if let previousView = previousView, !previousView.isEmpty {
            attrs[NRViewAttribute.previousView] = previousView
        }
        return attrs
    }

}

// MARK: - Transport

/// The single place view data leaves the agent.
internal enum NRMobileViewEmitter {

    internal static var isViewTrackingEnabled: Bool {
        NRMAFlags.shouldEnableAutomaticMobileViews() || NRMAFlags.shouldEnableManualMobileViews()
    }

    /// The manual API and the automatic producers are gated by different flags, so a
    /// customer can enable one without the other.
    internal static func isEnabled(for framework: NRViewFramework?) -> Bool {
        switch framework {
        case .some(.manual):
            return NRMAFlags.shouldEnableManualMobileViews()
        case .some(.uiKit), .some(.swiftUI):
            return NRMAFlags.shouldEnableAutomaticMobileViews()
        case .none:
            // No platform recorded. Only an automatic producer can get here, so the automatic
            // flag is the one that decides.
            return NRMAFlags.shouldEnableAutomaticMobileViews()
        }
    }

    /// Goes to NRMAAnalytics directly rather than through `+[NewRelic recordCustomEvent:]`,
    /// because MobileView and MobileViewTiming are reserved event types that the custom-event
    /// path refuses. The shutdown check that path performed has to be carried over here --
    /// without it a shut-down agent would keep emitting view events.
    internal static func send(_ attributes: [String: Any], timing: Bool) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown,
              let analytics = agent.analyticsController else { return false }

        return timing
            ? analytics.addViewTimingEvent(attributes: attributes)
            : analytics.addMobileViewEvent(attributes: attributes)
    }
}

// MARK: - Objective-C facade

/// Fields for one MobileView event, as seen from Objective-C.
///
/// A settable payload rather than a wide selector: the Objective-C producers each fill in
/// what they know and hand it over. It carries no logic -- `MobileViewRecord` remains the
/// single owner of the schema, and this only maps onto it.
@objcMembers
public class NRMAMobileViewFields: NSObject {
    public var viewName: String = ""
    public var viewClass: String?
    public var instanceId: String = ""
    /// "UIKit", "SwiftUI" or "Manual". Anything else (including nil or empty) omits
    /// `uiFramework` -- unless `manual` is set, when it is written verbatim and nil or empty
    /// writes "Manual".
    public var uiFramework: String?
    /// Set by the manual setCurrentView: producer. The event is gated by the manual flag and
    /// `uiFramework` is whatever its caller declared, not a toolkit the agent observed.
    public var manual: Bool = false
    /// Milliseconds. Setting this writes `loadTime`; it wins over `loadTimeUnavailable`.
    public var loadTimeMs: NSNumber?
    /// One of "noLoadStartDeclared", "noConstructionObserved", "notRebuilt".
    public var loadTimeUnavailable: String?
    /// Milliseconds. Setting this writes `timeVisible`.
    public var timeVisibleMs: NSNumber?
    /// Merge `previousView` / `previousViewInstanceId` out of the shared view context.
    /// Ignored when `previousView` is set explicitly.
    public var useContextReferrer: Bool = false
    public var previousView: String?
    public var previousViewInstanceId: String?
    public var custom: [String: Any]?
    internal private(set) var composition: NRViewComposition?

    /// What the producer saw of the view tree. Unset omits all three attributes, which is right only
    /// for a producer that never sees the screen.
    @objc(setContainsWebView:isFullScreenWebView:isTopLevelView:)
    public func setComposition(containsWebView: Bool, isFullScreenWebView: Bool, isTopLevelView: Bool) {
        composition = NRViewComposition(containsWebView: containsWebView,
                                        isFullScreenWebView: isFullScreenWebView,
                                        isTopLevelView: isTopLevelView)
    }

    internal func record() -> MobileViewRecord? {
        guard !viewName.isEmpty else { return nil }

        let referrer: NRViewReferrer
        if let previousView = previousView, !previousView.isEmpty {
            referrer = .explicit(name: previousView, instanceId: previousViewInstanceId)
        } else if useContextReferrer {
            referrer = .fromContext
        } else {
            referrer = .none
        }

        let load: NRViewLoadOutcome?
        if let loadTimeMs = loadTimeMs {
            load = .measured(loadTimeMs.doubleValue)
        } else if let reason = loadTimeUnavailable,
                  let parsed = NRViewLoadOutcome.Reason(rawValue: reason) {
            load = .unavailable(parsed)
        } else if loadTimeUnavailable != nil {
            load = .unavailable(.noConstructionObserved)
        } else {
            load = nil
        }

        return MobileViewRecord(
            viewName: viewName,
            viewClass: viewClass,
            instanceId: instanceId,
            framework: manual ? .manual : uiFramework.flatMap { NRViewFramework(rawValue: $0) },
            declaredFramework: manual ? uiFramework : nil,
            referrer: referrer,
            load: load,
            timeVisibleMs: timeVisibleMs?.doubleValue,
            composition: composition,
            custom: custom)
    }
}

/// The Objective-C entry point to the shared emitter.
@objcMembers
public class NRMAMobileViewRecorder: NSObject {

    /// Emits the single MobileView event for one completed visit.
    public static func record(_ fields: NRMAMobileViewFields) {
        fields.record()?.emit()
    }

    /*
     * The MobileViewTiming schema.
     *
     * Split from emission because the two halves have different owners: NRMAViewTiming owns
     * admission policy -- name and duration validation, and the per-view-instance cap, which
     * needs its own lock and mutates bucket state -- while this owns the event's shape. Having
     * NRMAViewTiming build its own dictionary too is what let `agentName` diverge between the
     * two in the first place.
     */
    public static func timingAttributes(_ timingName: String,
                                        milliseconds: Double,
                                        viewName: String?,
                                        viewInstanceId: String?,
                                        previousView: String?) -> [String: Any] {
        ViewTimingRecord(
            timingName: timingName,
            timingValueMs: milliseconds,
            viewName: viewName,
            viewInstanceId: viewInstanceId,
            previousView: previousView).attributes()
    }

    /// Emits attributes built by `timingAttributes(...)`. Timing rows describe a view, so either
    /// producer being enabled is enough -- matching what NRMAViewTiming enforced for itself.
    public static func emitTiming(attributes: [String: Any]) -> Bool {
        guard NRMobileViewEmitter.isViewTrackingEnabled else { return false }
        return NRMobileViewEmitter.send(attributes, timing: true)
    }
}

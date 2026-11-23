//
//  SecureLabel.swift
//  NRTestApp
//
//  Created by Mike Bruin on 7/11/25.
//

import UIKit

#if os(iOS) || os(tvOS)

class SecureLabel: UILabel {

}

class UnsecureLabel: UILabel {

}

// Registered as "NRTestApp.ModuleMaskedLabel": a module prefix is accepted and ignored.
class ModuleMaskedLabel: UILabel {

}

// Registered as "NRTestApp.ModuleUnmaskedLabel": the unmask counterpart of ModuleMaskedLabel.
class ModuleUnmaskedLabel: UILabel {

}

// Not registered itself. Class rules match exactly, so inheriting from SecureLabel does not mask it.
class SubSecureLabel: SecureLabel {

}

#endif

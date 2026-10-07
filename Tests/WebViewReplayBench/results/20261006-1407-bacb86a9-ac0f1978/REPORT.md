# WebView replay bench -- Phase 0

- webview-msr-poc @ `bacb86a9`, two-streams-webview-msr @ `ac0f1978`
- host: ProductName:		macOS / ProductVersion:		26.6.1 / BuildVersion:		25G76 / Apple M3 Max / swift-driver version: 1.168.6 Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
- times are medians on this Mac; expect a low-end iPhone to be several times slower

## Native ingest (parse queue), per WebView

Document = one Meta + FullSnapshot bridge message. CPU/min = one document + one minute of changes at that branch's batch cadence.

| page | view | variant | payload | doc bridge MB | doc ingest ms | peak RSS Δ MB | change batch ms | CPU ms/min |
|---|---|---|---|---|---|---|---|---|
| small (400 nodes) | as shipped | poc | rrweb | 0.07 | 2.3 | 2.2 | 0.48 (1s) | 31 |
| small (400 nodes) | as shipped | twostreams | agent | 0.14 | 1.0 | 1.8 | 0.95 (5s) | 12 |
| small (400 nodes) | same input | poc | agent | 0.14 | 2.5 | 2.3 | 0.51 (1s) | 33 |
| small (400 nodes) | same input | twostreams | agent | 0.14 | 1.0 | 1.8 | 0.95 (5s) | 12 |
| medium (4,000 nodes) | as shipped | poc | rrweb | 0.66 | 22.2 | 7.0 | 0.53 (1s) | 54 |
| medium (4,000 nodes) | as shipped | twostreams | agent | 1.37 | 9.7 | 4.6 | 0.91 (5s) | 21 |
| medium (4,000 nodes) | same input | poc | agent | 1.37 | 24.2 | 7.7 | 0.57 (1s) | 58 |
| medium (4,000 nodes) | same input | twostreams | agent | 1.37 | 9.7 | 4.6 | 0.91 (5s) | 21 |
| large (16,000 nodes) | as shipped | poc | rrweb | 2.64 | 89.0 | 22.9 | 0.34 (1s) | 109 |
| large (16,000 nodes) | as shipped | twostreams | agent | 5.51 | 39.0 | 10.7 | 1.04 (5s) | 51 |
| large (16,000 nodes) | same input | poc | agent | 5.51 | 96.4 | 22.9 | 0.36 (1s) | 118 |
| large (16,000 nodes) | same input | twostreams | agent | 5.51 | 39.0 | 10.7 | 1.04 (5s) | 51 |

## Harvest, steady state (mean of chunks 1-5, 60s chunks, 1 WebView)

| page | native activity | view | variant | doc copies | WebView raw KB | chunk gz KB | docs shed | carried KB | build ms | encode+gzip ms |
|---|---|---|---|---|---|---|---|---|---|---|
| medium | normal | as shipped | poc | 1.0 | 1,030 | 276 | 0 | 891 | 0.34 | 34.3 |
| medium | normal | as shipped | twostreams | 1.0 | 1,078 | 263 | 0 | 647 | 0.07 | 31.0 |
| medium | normal | same input | poc | 1.0 | 1,030 | 277 | 0 | 891 | 0.34 | 34.4 |
| medium | normal | same input | twostreams | 1.0 | 1,078 | 263 | 0 | 647 | 0.07 | 31.0 |
| medium | +3 native FS/chunk | as shipped | poc | 4.0 | 3,380 | 817 | 0 | 891 | 0.58 | 105.2 |
| medium | +3 native FS/chunk | as shipped | twostreams | 4.0 | 3,013 | 708 | 0 | 647 | 0.07 | 85.3 |
| medium | +3 native FS/chunk | same input | poc | 4.0 | 3,380 | 817 | 0 | 891 | 0.58 | 106.5 |
| medium | +3 native FS/chunk | same input | twostreams | 4.0 | 3,013 | 708 | 0 | 647 | 0.07 | 85.3 |
| medium | +10 iframe moves/chunk | as shipped | poc | 11.0 | 8,758 | 858 | 30 | 891 | 1.09 | 181.1 |
| medium | +10 iframe moves/chunk | as shipped | twostreams | 1.0 | 1,078 | 263 | 0 | 647 | 0.07 | 31.3 |
| medium | +10 iframe moves/chunk | same input | poc | 11.0 | 8,758 | 858 | 30 | 891 | 1.09 | 180.9 |
| medium | +10 iframe moves/chunk | same input | twostreams | 1.0 | 1,078 | 263 | 0 | 647 | 0.07 | 31.3 |
| large | normal | as shipped | poc | 1.0 | 3,038 | 666 | 0 | 2,891 | 0.37 | 89.4 |
| large | normal | as shipped | twostreams | 1.0 | 3,031 | 621 | 0 | 2,588 | 0.07 | 79.0 |
| large | normal | same input | poc | 1.0 | 3,038 | 666 | 0 | 2,891 | 0.37 | 89.6 |
| large | normal | same input | twostreams | 1.0 | 3,031 | 621 | 0 | 2,588 | 0.07 | 79.0 |
| large | +3 native FS/chunk | as shipped | poc | 4.0 | 11,410 | 785 | 15 | 2,891 | 0.69 | 215.6 |
| large | +3 native FS/chunk | as shipped | twostreams | 4.0 | 10,787 | 704 | 15 | 2,588 | 0.07 | 179.2 |
| large | +3 native FS/chunk | same input | poc | 4.0 | 11,410 | 785 | 15 | 2,891 | 0.69 | 214.8 |
| large | +3 native FS/chunk | same input | twostreams | 4.0 | 10,787 | 704 | 15 | 2,588 | 0.07 | 179.2 |
| large | +10 iframe moves/chunk | as shipped | poc | 11.0 | 30,839 | 706 | 50 | 2,891 | 1.38 | 474.6 |
| large | +10 iframe moves/chunk | as shipped | twostreams | 1.0 | 3,031 | 621 | 0 | 2,588 | 0.07 | 79.3 |
| large | +10 iframe moves/chunk | same input | poc | 11.0 | 30,839 | 707 | 50 | 2,891 | 1.38 | 477.7 |
| large | +10 iframe moves/chunk | same input | twostreams | 1.0 | 3,031 | 621 | 0 | 2,588 | 0.07 | 79.3 |

## Browser agent `TOO_BIG` exposure (two-streams only)

The observation agent gzips each replay harvest without `__serialized` and aborts replay for the rest of the session when it exceeds 1,000,000 bytes. The harvest holding the FullSnapshot is the largest, so this is the page size at which two-streams stops recording.

| page | snapshot JSON MB | gzipped KB | ratio | over cap? |
|---|---|---|---|---|
| small | 0.07 | 13 | 20.6% | no |
| medium | 0.66 | 122 | 18.9% | no |
| large | 2.64 | 481 | 18.7% | no |

At these fixtures' ~19% ratio the cap is reached by a ~5.2 MB snapshot. Synthetic text compresses differently from real pages (inlined CSS compresses better, base64 images far worse), so the real threshold must come from Phase 1 captures.

# popup

A native UIKit popup bar and full-screen presentation for iOS.

## Features

- Shared, interruptible bar ↔ full-screen transitions with optional shared artwork.
- Apple Music-style drag-to-open and drag-to-close, rubber-banding, and velocity-aware springs.
- Concentric capsule, artwork, and button styling; configurable height and content-fitting width.
- Marquee titles and subtitles, attributed titles, and live content updates.
- Docking above tab bars, navigation toolbars, or a custom view such as a chat composer.
- iOS 26 tab bottom accessory integration, including inline/minimized layouts.

## Requirements

- iOS 18 or later; UIKit.
- Swift 6.4 or later (the package declares `swift-tools-version: 6.4`). Use an Xcode toolchain that supports it and the iOS 26 SDK for the tab accessory APIs.

## Installation

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/gtokman/popup.git`, and add the **popup** library product to your app target.

## Quick start

Import `popup`, configure the **content controller's** `popupItem`, and present the bar on the hosting controller. This example uses a tab bar controller; the same presentation methods are available on any `UIViewController`.

```swift
import UIKit
import popup

final class PlayerContentViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Build your full-screen player UI here.
    }
}

final class MusicTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let library = UIViewController()
        library.view.backgroundColor = .systemBackground
        library.tabBarItem = UITabBarItem(
            title: "Library", image: UIImage(systemName: "music.note"), tag: 0
        )
        viewControllers = [library]

        let player = PlayerContentViewController()
        player.popupItem.title = "Now Playing"
        player.popupItem.subtitle = "Artist"
        player.popupItem.image = UIImage(systemName: "music.note")
        presentPopupBar(with: player, animated: false)
    }
}
```

Tap the bar or drag it upward to open; drag the content downward to close. You can also call `openPopup(animated:)`, `closePopup(animated:)`, and `dismissPopupBar(animated:)` on the host. Closing returns to the bar; dismissing removes it. The content controller can call `closePopup(animated:)` directly, or access its host through `popupContainer`.

## Customization

- **Content:** update `popupItem.title`, `attributedTitle`, `subtitle`, `image`, and `barButtonItems` (an array of `UIBarButtonItem`). Changes update the bar automatically.
- **Bar:** use the host's `popupBar` (`PopupBar`) to set `preferredHeight` (default 56), `horizontalMargin` (12), `widthMode` (`.fill` or `.fitsContent`), `showsImageBackground`, and `marqueeScrollEnabled`.
- **Docking:** set `popupController.dockingAnchorView` to dock above a view, and `barSpacing` to adjust the gap (default 6).
- **Presentation:** `popupController.backgroundScale`, `dimmingAlpha`, and `openCornerRadius` control the expanded appearance. Set `openSpring`, `closeSpring`, and `settleSpring` using `PopupSpring(response:dampingRatio:)` to tune motion.
- **Shared artwork:** adopt `PopupContentTransitioning` on your content controller and return its artwork view from `var popupArtworkView: UIView? { get }`.
- **Tab accessory:** `popupController.usesTabBarAccessory` defaults to `true` for `UITabBarController` hosts on iOS 26+. Set it to `false` for a floating bar instead. Earlier iOS versions use floating docking.

## Examples

Open `Example/PopupExample/PopupExample.xcodeproj`, select the **PopupExample** scheme and an iPhone simulator, then run. For a physical device, select your signing team. The app references the package locally; `project.yml` is available if you want to regenerate the project with XcodeGen.

The example picker contains:

| Demo | Shows |
| --- | --- |
| Apple Music | Artwork-led player with shared artwork transitions and playback controls. |
| Apple Music · Tab accessory (iOS 26) | Searchable library and inline popup accessory; use iOS 26+ for accessory behavior. |
| Tasks | Checklist with live title and progress-image updates. |
| Agent chat · Tasks | Task popup docked above a growing chat composer. |
| Coding · Files changed | Compact, content-fitting attributed change summary above a composer. |

## Running tests

Open `Package.swift` in Xcode, select the package's **popup** scheme and an iOS simulator destination, and choose **Product → Test** (⌘U). Tests use Swift Testing and cover item observation, bar layout, docking, marquee behavior, spring dynamics, and gesture math.

`swift build` / `swift test` on a macOS host do not target iOS by default; this UIKit package needs an iOS SDK/destination as well as the required Swift toolchain.

## License

[MIT](LICENSE).

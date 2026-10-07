# Harbor app icon

`Harbor.icon` is the editable Icon Composer document. It contains three 1024 × 1024 vector layers: the ivory harbor arch, warm sun, and blue water reflection. The navy background, glass, and shadows are rendered by Icon Composer.

Open `Harbor.icon` in Icon Composer to edit. Default, Dark, and Mono appearances were visually checked in Composer. The PNGs in `previews/` are flattened iOS previews exported with Apple’s `ictool` using design generation 26. They are for review, not a replacement for the layered document.

## App integration

Once the Xcode app project exists, add the entire `Harbor.icon` document to the project and app target. Select `Harbor` as the app icon in the target’s General settings (App Icons and Launch Screen); the App Icon asset name build setting is `ASSETCATALOG_COMPILER_APPICON_NAME = Harbor`. Build and verify on a device or simulator before release.

The workspace did not contain an Xcode project when this icon was created, so target integration and an app build have not been performed.

Original editable SVG artwork is retained in `layers/`. Changes to those source files must be imported into the corresponding Composer layers; the document keeps its own copies in `Harbor.icon/Assets/`.

Apple guidance: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer

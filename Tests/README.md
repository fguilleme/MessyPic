# Vérifications de l’analyse / Photo analysis checks

[Français](#français) · [English](#english) · [MessyPic](../README.md)

## Français

Depuis la racine du projet, sur macOS avec Xcode installé :

```sh
xcrun swiftc -module-cache-path /tmp/MessyPicSwiftModuleCache -swift-version 5 MessyPic/PhotoModels.swift MessyPic/PhotoAnalyzer.swift Tests/PhotoAnalyzerChecks.swift -o /tmp/MessyPicPhotoAnalyzerChecks
/tmp/MessyPicPhotoAnalyzerChecks
```

Les vérifications couvrent l’alignement du masque du sujet en portrait et en paysage, le repli sur toute la photo si le masque est invalide, la priorité d’un vêtement jaune saturé sur des tons de peau peu saturés, les sujets neutres ou bruns, le turquoise, la priorité de `night_sky` sur les étiquettes génériques de ciel ou de document, ainsi que le décodage des anciens caches et la sérialisation des nouveaux.

Un argument facultatif accepte le chemin d’une capture de référence de la robe turquoise, au format original **590 × 1280 pixels**. Le test recadre la photo en mémoire sous la barre de navigation de 170 pixels, sur une hauteur de 1070 pixels, et vérifie que le pipeline Vision complet la classe en Turquoise. L’accès aux services système des modèles Vision est nécessaire. Ces captures personnelles ne sont pas incluses dans le dépôt.

Pour la capture de référence du sweat jaune, préciser la catégorie attendue et la hauteur de la photo :

```sh
/tmp/MessyPicPhotoAnalyzerChecks "/chemin/capture-sweat.jpg" Jaune 787
```

Les arguments sont : chemin de la capture, catégorie attendue (valeur française de `PhotoColorCategory`) et hauteur de la photo sous la barre de navigation. Ce recadrage est spécifique aux captures de référence, pas à des photos arbitraires.

## English

Run from the project root on macOS with Xcode installed:

```sh
xcrun swiftc -module-cache-path /tmp/MessyPicSwiftModuleCache -swift-version 5 MessyPic/PhotoModels.swift MessyPic/PhotoAnalyzer.swift Tests/PhotoAnalyzerChecks.swift -o /tmp/MessyPicPhotoAnalyzerChecks
/tmp/MessyPicPhotoAnalyzerChecks
```

The checks cover subject-mask alignment for portrait and landscape images, invalid-mask fallback, saturated yellow clothing against muted skin tones, neutral/brown subjects, turquoise classification, priority of `night_sky` over generic sky and document labels, and old/new cache decoding.

An optional argument accepts a turquoise-dress reference screenshot in its original **590 × 1280 pixel** format. It crops the photograph in memory below the 170-pixel navigation bar, using a height of 1070 pixels, and verifies that the full Vision pipeline classifies it as Turquoise. Vision must have access to the system model services for this integration check. These personal reference screenshots are not included in the repository.

For the yellow-hoodie reference screenshot, specify the expected category and the photograph’s height:

```sh
/tmp/MessyPicPhotoAnalyzerChecks "/path/to/hoodie-screenshot.jpg" Jaune 787
```

Arguments are: screenshot path, expected category (the French raw value of `PhotoColorCategory`) and photograph height below the navigation bar. This crop is specific to the reference screenshots, not arbitrary photos.

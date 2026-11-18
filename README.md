# EcoVision

Application Flutter Android et API FastAPI. L’aperçu Flutter Web sert aux essais sur PC.

## Démarrer sous Windows

Dans un terminal à la racine du projet :

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

Dans un second terminal :

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5554
# Ou depuis Chrome
flutter run -d chrome
```

L’émulateur accède au serveur de la machine via 10.0.2.2. Pour un appareil physique, fournissez l’URL accessible par l’appareil avec `--dart-define=API_URL=...`. Pour un déploiement, utilisez HTTPS. La documentation de l’API est disponible sur http://127.0.0.1:8000/docs.

## Essayer les parcours

Le démarrage local ouvre le compte citoyen de démonstration avec 250 EcoPoints. Le menu de compte permet de passer aux interfaces agent, centre et administrateur. Déconnectez-vous pour tester l’inscription ou la connexion. Les centres, partenaires et codes d’échange de démonstration sont fictifs, et les actions sont stockées dans ecovision.db.

1. Dans Scanner, importez une photo ou choisissez directement la matière pour obtenir un conseil de tri.
2. Dans Carte, filtrez les centres ou utilisez le GPS, puis déclarez un dépôt auprès d’un centre disponible.
3. Passez au rôle Centre de recyclage et confirmez le dépôt. Revenez au rôle Citoyen pour voir les 25 points crédités et les échanger.
4. Créez un signalement avec le GPS ou des coordonnées saisies. Passez au rôle Agent de collecte pour consulter le signalement et modifier son état.

## Services à connecter

- **PostgreSQL**. Définissez `DATABASE_URL=postgresql+psycopg://utilisateur:motdepasse@hote:5432/ecovision`. Les tables sont créées au démarrage. Utilisez `ECOVISION_DEMO=0` pour désactiver les comptes, centres et récompenses de démonstration. Après inscription, un exploitant disposant d’un accès SQL peut promouvoir le premier administrateur via `UPDATE users SET role='admin' WHERE email='adresse-validée';`. Utilisez une base distincte de celle de démonstration.
- **Google Maps Android**. Activez Maps SDK for Android dans Google Cloud, fournissez `GOOGLE_MAPS_ANDROID_KEY` avant la compilation puis lancez avec `--dart-define=GOOGLE_MAPS_ENABLED=true`. Restreignez la clé au nom du package et au certificat de signature. La liste géolocalisée et les filtres fonctionnent sans clé. Pour intégrer Google Maps à l’aperçu Web, configurez aussi Maps JavaScript API sur la page hôte avec une clé dédiée.
- **TensorFlow Lite**. Installez `ai-edge-litert` et `numpy` dans un environnement compatible et définissez `ECOVISION_MODEL` sur le chemin du modèle. L’adaptateur Python attend une entrée RGB float32 [1, hauteur, largeur, 3] normalisée sur [0,1], et cinq probabilités float32 dans l’ordre plastique, papier/carton, verre, métal, organique. Une confiance inférieure à 65 % propose le choix manuel. Sans modèle, l’interface propose le guide manuel. Le modèle entraîné reste à fournir.
- **Intégrations métier**. Les signalements sont disponibles dans l’espace agent, sans routage par municipalité ni notification externe. Les codes sont enregistrés dans EcoVision et restent à relier aux systèmes des partenaires.

Pour servir une compilation Web déjà générée, exécutez `flutter build web --release`, puis :

```powershell
.\.venv\Scripts\python.exe -m http.server 8650 --bind 127.0.0.1 --directory build/web
```

Ouvrez http://127.0.0.1:8650/. Si Android utilise un NDK différent de celui demandé par Flutter, définissez `ECOVISION_ANDROID_NDK` sur la version compatible installée dans le SDK.

## Déboguer dans VS Code

Ouvrez la racine EcoVision dans VS Code. Dans Android Studio, ouvrez Device Manager et démarrez un émulateur. Dans VS Code, sélectionnez cet émulateur comme appareil, puis lancez la configuration « EcoVision · Flutter » avec F5. Gardez le serveur FastAPI actif dans un terminal.

Sur ce poste, si nécessaire, la propriété locale `ecovision.ndkVersion=30.0.16248370` dans `android/local.properties` sélectionne le NDK déjà installé. Ce fichier reste propre à la machine.

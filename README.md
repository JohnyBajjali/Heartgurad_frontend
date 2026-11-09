# HeartGuard — Flutter Application

Cross-platform application for **HeartGuard**, a Birzeit University graduation project combining ECG image digitisation and AI-based cardiac classification.

The Flutter client provides the user-facing workflow: patient records, ECG uploads, manual image cropping, result visualisation, notes, and case history. Signal processing and model inference run on the separate Django backend.

## Project Team

- Robert Bannoura
- Mahmoud Awad
- Johny Bajjali

**Supervisor:** Dr. Hanna Bullata  
**Department:** Electrical & Computer Engineering  
**Project report:** February 2026

HeartGuard is a collaborative project. This repository retains the original frontend Git history and contributor attribution. Johny's contribution focused on the application layer, including Flutter development, Django API integration, patient records, uploads, and presentation of prediction results; this does not imply sole authorship of the team's model work.

## Related Repositories

- [Django backend](https://github.com/JohnyBajjali/Heartguard_backend)
- [Original team frontend repository](https://github.com/RobertBannoura/heartguard-frontend)

Private repositories require access permission.

## Application Features

### Home and Navigation

A dashboard provides access to Patients, ECG upload/analysis, and the ECG reference gallery. The application includes light/dark theme support and a shared navigation shell.

### Patient Records

Create, list, and delete patient profiles. The patient dashboard brings together doctor notes, ECG intake, and previously uploaded ECG cases with stored predictions and preview information.

### ECG Intake

- Upload digital ECG files in Philips XML or HL7 aECG formats.
- Select ECG images from files or device-supported image sources.
- Select `3x4` or `3x4+1` layout metadata.
- Manually crop images before sending them to the backend.
- Upload the case and request prediction through backend APIs.

Image acquisition and cropping behavior depend on the target platform and available plugins. Selecting a layout does not by itself guarantee a distinct model pipeline; the backend controls processing.

### Results and History

The result interface presents available original/processed ECG images and model scores. Using the bundled label CSV, diagnostic results are grouped into:

| Code | Diagnostic group |
|---|---|
| NORM | Normal |
| MI | Myocardial infarction |
| STTC | ST/T changes |
| CD | Conduction disturbance |
| HYP | Hypertrophy |

These groups summarise returned diagnostic entries. They are not a separate five-output model: the backend fusion classifier is configured for 71 labels and returns a ranked subset. Scores do not establish a clinical diagnosis.

Stored ECG cases can be reopened from patient history. The code also includes patient-note and ECG-note service methods.

### ECG Reference Gallery

The gallery loads `assets/data/scp_statementsRegrouped2.csv`, supports text search and diagnostic-category filtering, and opens available reference links. This is an educational reference feature, not the inference engine.

## Technology Stack

- Flutter and Dart.
- HTTP JSON requests and multipart uploads using `http` and `http_parser`.
- File/image selection using `file_picker` and `image_picker`.
- Image cropping packages, including `crop_your_image` and `image_cropper`.
- CSV-based ECG label metadata.
- Local preferences using `shared_preferences`.
- Reference links using `url_launcher`.

The package declares a Dart SDK constraint of **`^3.9.2`**. Use a compatible Flutter SDK.

## Repository Structure

```text
lib/
  main.dart
  src/
    models/                    Patient data representation
    screens/                   Home, patients, patient details, gallery and cropping
    services/                  Upload/prediction, patients and notes API clients
    theme/                     Theme controller
    widgets/                   Router and shared application shell
assets/data/                   ECG label CSV
android/                       Android platform project
web/                           Web platform project
windows/                       Windows platform project
pubspec.yaml                   Dependencies and asset declarations
pubspec.lock                   Resolved package versions
```

The report includes mobile/iOS screenshots and discusses cross-platform use. The supplied repository snapshot contains Android, Web, and Windows platform directories; it does not include an `ios/` runner. It should not be described as a ready-to-build native iOS checkout without that platform setup.

## Running Locally

### 1. Get the source and dependencies

```powershell
git clone https://github.com/JohnyBajjali/Heartgurad_frontend.git
cd Heartgurad_frontend
flutter pub get
flutter devices
```

The repository name above matches its current GitHub spelling.

### 2. Prepare the backend

Follow the [backend documentation](https://github.com/JohnyBajjali/Heartguard_backend) to prepare PostgreSQL, Python dependencies, and Git LFS model weights. Start a backend reachable from the client before testing patient records, uploads, or prediction.

The frontend does not bundle a running backend, database, or model service.

### 3. Check backend addressing

The current addressing logic is in:

```text
lib/src/services/ecg_upload_service.dart
EcgUploadService.backendBaseUrl()
```

| Client target | Current behavior |
|---|---|
| Web | Uses `http://<web-page-host>:8000` |
| Android | Uses `http://10.0.2.2:8000`, intended for an Android emulator |
| Other native targets, including Windows | Uses the development LAN address `http://192.168.1.214:8000` |

This is development configuration, not a publicly hosted API. A different computer or physical phone needs an appropriate reachable backend address and networking setup; the hardcoded LAN address is not portable. The current code does not read a `--dart-define` override for this URL.

### 4. Launch a supported target

For Windows:

```powershell
flutter run -d windows
```

For an available Android emulator:

```powershell
flutter run -d <device-id>
```

Use the device identifier returned by `flutter devices`. Web support is described in the report and platform files are included, but a fresh web build was not verified during this repository review. The upload service also imports `dart:io`, so platform compatibility must be checked with the chosen SDK and target.

These instructions describe setup, not a claim that the application was freshly built and tested during portfolio preparation.

## Backend Integration

| Workflow | Backend route |
|---|---|
| Patient lookup/creation | `/api/patient/login_or_create/` |
| List/create patients | `/api/patients/` |
| Delete patient | `/api/patients/delete/` |
| Patient notes | `/api/patients/<id>/notes/` |
| ECG upload | `/api/ecg/upload/` |
| Automatic crop | `/api/ecg/auto_crop/` |
| Model prediction | `/api/ecg/predict/` |
| Patient ECG history | `/api/ecg/list/?patient_id=<id>` |
| ECG deletion | `/api/ecg/delete/` |
| ECG notes | `/api/ecg/notes/` |

The service layer sends requests, handles status codes, and decodes responses for presentation. Model inference is performed by the backend, not on the Flutter device.

## Project Report and Visual Documentation

The official team report is **“Heart Guard: An AI-Based System for ECG Image Digitisation and Cardiac Diagnosis”**, February 2026. Chapter 8 documents the application and backend implementation.

Useful figures for understanding the application include:

| Figure | Content | Printed report page |
|---|---|---:|
| 8.1–8.2 | Home dashboard in light/dark mode | 77–78 |
| 8.4 | Patient management | 80 |
| 8.6 | Patient dashboard, notes and case history | 82 |
| 8.7–8.9 | Upload workflow and input selection | 83–84 |
| 8.10–8.11 | ECG preview and prediction scores | 85 |
| 8.15 | Manual cropping | 89 |

The report and screenshots are not bundled by this README. Public screenshots should use demo/de-identified data and omit identifying names, IDs, and report headers. The report describes the overall project; the source tree and configuration describe the particular checkout.

## Scope

HeartGuard is a graduation research prototype. Its interface supports reviewing and organising ECG-related information; it does not establish clinical approval or diagnostic validity. Running the app against real patient data requires appropriate access control, secure networking/storage, and clinical/privacy review beyond the supplied development setup.

## Attribution

Originally maintained at [RobertBannoura/heartguard-frontend](https://github.com/RobertBannoura/heartguard-frontend). This copy preserves the collaborative Git history. See the team report for the wider system, model methodology, evaluation, and research references.

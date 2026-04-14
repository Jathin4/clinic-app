# ClinicOS — Flutter App

A full-featured clinic management mobile app built with Flutter, mirroring the ClinicOS web application.

## 🚀 Quick Setup

### 1. Configure your API server
Open `lib/services/api_client.dart` and change **one line**:
```dart
static const String baseUrl = 'http://10.11.1.128:5020';
//                             ^^^^ Change this to your server IP/domain
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run the app
```bash
flutter run
```

---

## 📱 Screens & Features

| Screen | Features |
|--------|---------|
| **Login** | Email/password login, first-login password setup |
| **Dashboard** | KPI cards, appointments per doctor chart, payment modes, today's appointments, recent payments |
| **Patients** | List, search, add/edit/delete, view patient detail, gender/blood group badges |
| **Appointments** | List with status badges, book new appointment, delete |
| **Encounters** | List, add/edit/delete, patient & doctor selection, date pickers, chief complaint, notes |
| **Bills** | List, add/edit/delete, auto invoice number, patient+encounter linking, subtotal/GST/discount/total |
| **Payments** | List with Cash/Card/UPI filter, record new payment, linked to bills |
| **Inventory** | IN/OUT stock management, categories, stock level badges, expiry tracking, add/edit/delete |
| **Clinics** | List, 2-step add/edit form (details + contact), delete |
| **Users** | List by role, add/edit, Doctor specialization field, active/inactive toggle |

## 🔐 Role-Based Access

| Role | Access |
|------|--------|
| Admin | All sections |
| Doctor | Dashboard, Patients, Appointments, Encounters |
| Receptionist | Dashboard, Patients, Appointments, Encounters |
| Pharmacist | Dashboard, Patients, Appointments, Encounters, Bills, Payments, Inventory |
| Diagnosist | Dashboard, Patients, Appointments, Encounters, Bills, Payments, Reports |

## 🎨 Design
- Primary color: `#0E6C68` (teal)
- Font: Inter / system-ui
- Responsive: sidebar on tablet/desktop, hamburger on mobile

## 📦 Dependencies
- `provider` — state management
- `http` — API calls
- `shared_preferences` — session persistence
- `intl` — date formatting

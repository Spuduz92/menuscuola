# MenuScuola 🥗

App Flutter per consultare i menu delle mense scolastiche italiane.

## Stack
- **Flutter** 3.x (iOS + Android)
- **Supabase** (Auth, Database, Storage, Realtime)
- **Riverpod** (State management)
- **GoRouter** (Navigazione con guard ruoli)

---

## Setup rapido

### 1. Supabase

1. Crea un nuovo progetto su [supabase.com](https://supabase.com)
2. Vai in **SQL Editor** ed esegui tutto il contenuto di `supabase_schema.sql`
3. Vai in **Storage** e crea due bucket pubblici:
   - `school-logos`
   - `menu-pdfs`
4. Copia **Project URL** e **anon key** da *Settings → API*

url: https://zulrgaskplmboehtdztm.supabase.co/rest/v1/
anon: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1bHJnYXNrcGxtYm9laHRkenRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4NzY2ODQsImV4cCI6MjA5MjQ1MjY4NH0.F-f6ZnL_KDTUeX73C0q7fE_IN4W2JQ_PWNJekRdWtT8

### 2. Configura le credenziali

Apri `lib/core/supabase/supabase_client.dart` e sostituisci:

```dart
const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const supabaseAnonKey = 'YOUR_ANON_KEY';
```

### 3. Dipendenze Flutter

```bash
flutter pub get
```

### 4. Avvia l'app

```bash
flutter run
```

---

## Struttura del progetto

```
lib/
├── main.dart                          # Entry point
├── app/
│   ├── router.dart                    # GoRouter + guard ruoli
│   └── theme.dart                     # Design system completo
├── core/
│   ├── models/models.dart             # Tutti i modelli dati
│   └── supabase/supabase_client.dart  # Client Supabase
└── features/
    ├── auth/                          # Login, register utente/scuola
    ├── home/                          # Home utente, profilo, shell
    ├── search/                        # Ricerca per nome o zona
    ├── school_detail/                 # Dettaglio scuola + PDF viewer
    └── school_dashboard/              # Dashboard scuola + editor menu
```

---

## Ruoli utente

| Ruolo   | Accesso |
|---------|---------|
| `user`  | Visualizza menu, salva preferiti, cerca scuole |
| `school`| Dashboard, crea/modifica menu, carica PDF |
| `admin` | Approva scuole (da implementare nel pannello admin) |

---

## Aggiunte necessarie prima del deploy

- [ ] Aggiungere `image_picker` al `pubspec.yaml` (per upload logo scuola)
- [ ] Aggiungere tutte le regioni/province/comuni italiani al DB (o importare da open data ISTAT)
- [ ] Creare pannello admin per approvazione scuole
- [ ] Configurare notifiche push (Firebase Cloud Messaging o Supabase Realtime)
- [ ] Aggiungere `flutter_localizations` per date in italiano
- [ ] App Store / Play Store setup

---

## Comandi utili

```bash
# Aggiorna dipendenze
flutter pub get

# Analisi codice
flutter analyze

# Build release Android
flutter build appbundle --release

# Build release iOS
flutter build ipa --release
```

---

## Design system

| Token | Valore |
|-------|--------|
| `forest` | `#2D4A3E` — colore primario |
| `terracotta` | `#C4623A` — accento / CTA |
| `sage` | `#7FA688` — successo / preferiti |
| `cream` | `#FAF7F2` — sfondo |
| Font display | Playfair Display |
| Font body | DM Sans |

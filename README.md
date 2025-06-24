# Pump Management System

A Flutter application for managing pump systems with QR code scanning and chatbot integration.

## Features

- Site creation and management
- Automatic pump setup for each site
- QR code generation and scanning
- Chatbot-based pump updates
- Real-time data synchronization with Supabase

## Prerequisites

- Flutter SDK
- Supabase account
- OpenAI API key
- OpenCage API key

## Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd pump_management_system
```

2. Install dependencies:
```bash
flutter pub get
```

3. Create a `.env` file in the root directory with the following variables:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
OPENAI_API_KEY=your_openai_api_key
OPENCAGE_API_KEY=your_opencage_api_key
```

4. Set up Supabase:
   - Create a new project in Supabase
   - Create the following tables:

   ```sql
   -- Sites table
   create table sites (
     id uuid default uuid_generate_v4() primary key,
     site_name text not null,
     site_owner text not null,
     site_owner_email text not null,
     site_owner_phone text not null,
     site_manager text not null,
     site_manager_email text not null,
     site_manager_phone text not null,
     site_inspector_name text not null,
     site_inspector_email text not null,
     site_inspector_phone text not null,
     site_inspector_photo text,
     site_location text not null,
     created_at timestamp with time zone default timezone('utc'::text, now()) not null
   );

   -- Pumps table
   create table pumps (
     id uuid default uuid_generate_v4() primary key,
     site_id uuid references sites(id) on delete cascade not null,
     name text not null,
     capacity integer not null,
     head integer not null,
     rated_power integer not null,
     uid text not null unique,
     qr_image_url text,
     status text not null,
     mode text not null,
     start_pressure decimal not null,
     stop_pressure decimal not null,
     suction_valve text not null,
     delivery_valve text not null,
     pressure_gauge text not null,
     created_at timestamp with time zone default timezone('utc'::text, now()) not null,
     updated_at timestamp with time zone default timezone('utc'::text, now()) not null
   );
   ```

   - Create storage buckets:
     - `inspector_photos` for storing inspector photos
     - `qr_codes` for storing QR code images

5. Run the application:
```bash
flutter run
```

## Usage

1. Create a new site by providing site details
2. The system will automatically create 8 standard pumps for the site
3. Scan QR codes to view and update pump details
4. Use the chatbot interface to update pump information through natural conversation

## Dependencies

- flutter_chat_ui: ^1.6.8
- flutter_chat_types: ^3.7.0
- supabase_flutter: ^2.0.0
- qr_flutter: ^4.1.0
- mobile_scanner: ^3.5.5
- opencage: ^1.0.0
- http: ^1.1.0
- image_picker: ^1.0.4
- shared_preferences: ^2.2.0
- flutter_dotenv: ^5.1.0
- intl: ^0.18.1
- uuid: ^4.2.1
- image: ^4.0.15
- path_provider: ^2.1.1
- permission_handler: ^11.0.1

## License

This project is licensed under the MIT License - see the LICENSE file for details.

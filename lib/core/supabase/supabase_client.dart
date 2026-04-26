import 'package:supabase_flutter/supabase_flutter.dart';

// Sostituisci con i tuoi valori dal progetto Supabase
const supabaseUrl = 'https://zulrgaskplmboehtdztm.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1bHJnYXNrcGxtYm9laHRkenRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4NzY2ODQsImV4cCI6MjA5MjQ1MjY4NH0.F-f6ZnL_KDTUeX73C0q7fE_IN4W2JQ_PWNJekRdWtT8';

SupabaseClient get supabase => Supabase.instance.client;

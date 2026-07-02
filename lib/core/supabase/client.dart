import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level accessor for the Supabase client.
///
/// Usage:
///   supabase.from('trips').select()
///   supabase.auth.currentUser
SupabaseClient get supabase => Supabase.instance.client;

// SupabaseService.swift
// Provides the single shared SupabaseClient instance used across the app for
// authentication and (future) remote data persistence.
//
// ⚠️  The anon key below is safe to ship in client code — it only grants
//     row-level access permitted by Supabase RLS policies.
//     Never commit a service-role key here.

import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseKey
        )
    }
}

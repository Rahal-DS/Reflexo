//
//  AppUser.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 11/10/2025.
//

import FirebaseFirestore

/// A canonical representation of a signed-in Reflexo user.
///
/// This model is stored in Firestore at the path `users/{uid}`.
///
/// - Important: `id` mirrors the Firestore document ID and should equal `uid`.
///   Keep these in sync by always writing the document at `users/{uid}`.
struct AppUser: Codable, Identifiable {
    
    /// Firestore document identifier (should match the Firebase Auth UID).
    @DocumentID var id: String?
    let uid: String
    
    /// User’s email address.
    let email: String
    
    /// Public, unique display name shown in leaderboards and profile screens.
    var displayName: String
    
    /// Free-text country string.
    var country: String
    
    /// Date of birth in ISO-8601 calendar date form: `yyyy-MM-dd`.
    var dob: String // ISO8601 (yyyy-MM-dd)
    
    /// When the profile was first created.
    /// Commonly filled from a Firestore server timestamp field. If you use server timestamps,
    var createdAt: Date?
    
    /// When the profile was last updated.
    /// Also typically populated by Firestore server timestamps on update.
    var updatedAt: Date?
}

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5"
  }
  public: {
    Tables: {
      app_users: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          id: string
          last_active_profile_id: string | null
          locale: string
          region: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          last_active_profile_id?: string | null
          locale?: string
          region?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          last_active_profile_id?: string | null
          locale?: string
          region?: string
        }
        Relationships: [
          {
            foreignKeyName: "app_users_last_active_profile_fk"
            columns: ["last_active_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      media_titles: {
        Row: {
          age_rating: string | null
          backdrop_url: string | null
          created_at: string
          director: string | null
          genres: string[] | null
          id: string
          imdb_id: string | null
          imdb_rating: number | null
          overview: string | null
          poster_url: string | null
          raw_omdb: Json | null
          raw_tmdb: Json | null
          runtime_minutes: number | null
          starring: string[] | null
          title: string
          tmdb_id: number
          tmdb_type: string
          updated_at: string
          year: number | null
        }
        Insert: {
          age_rating?: string | null
          backdrop_url?: string | null
          created_at?: string
          director?: string | null
          genres?: string[] | null
          id?: string
          imdb_id?: string | null
          imdb_rating?: number | null
          overview?: string | null
          poster_url?: string | null
          raw_omdb?: Json | null
          raw_tmdb?: Json | null
          runtime_minutes?: number | null
          starring?: string[] | null
          title: string
          tmdb_id: number
          tmdb_type: string
          updated_at?: string
          year?: number | null
        }
        Update: {
          age_rating?: string | null
          backdrop_url?: string | null
          created_at?: string
          director?: string | null
          genres?: string[] | null
          id?: string
          imdb_id?: string | null
          imdb_rating?: number | null
          overview?: string | null
          poster_url?: string | null
          raw_omdb?: Json | null
          raw_tmdb?: Json | null
          runtime_minutes?: number | null
          starring?: string[] | null
          title?: string
          tmdb_id?: number
          tmdb_type?: string
          updated_at?: string
          year?: number | null
        }
        Relationships: []
      }
      profile_preferences: {
        Row: {
          answers: Json
          created_at: string
          id: string
          profile_id: string
          updated_at: string
        }
        Insert: {
          answers?: Json
          created_at?: string
          id?: string
          profile_id: string
          updated_at?: string
        }
        Update: {
          answers?: Json
          created_at?: string
          id?: string
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_preferences_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_title_interactions: {
        Row: {
          action: Database["public"]["Enums"]["interaction_action"]
          created_at: string
          extra: Json
          id: string
          profile_id: string
          rating: number | null
          session_id: string | null
          source: string | null
          title_id: string
        }
        Insert: {
          action: Database["public"]["Enums"]["interaction_action"]
          created_at?: string
          extra?: Json
          id?: string
          profile_id: string
          rating?: number | null
          session_id?: string | null
          source?: string | null
          title_id: string
        }
        Update: {
          action?: Database["public"]["Enums"]["interaction_action"]
          created_at?: string
          extra?: Json
          id?: string
          profile_id?: string
          rating?: number | null
          session_id?: string | null
          source?: string | null
          title_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_title_interactions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_title_interactions_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "recommendation_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_title_interactions_title_id_fkey"
            columns: ["title_id"]
            isOneToOne: false
            referencedRelation: "media_titles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          context_type: string | null
          created_at: string
          deleted_at: string | null
          description: string | null
          emoji: string | null
          id: string
          is_default: boolean
          name: string
          updated_at: string
          user_id: string
        }
        Insert: {
          avatar_url?: string | null
          context_type?: string | null
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          emoji?: string | null
          id?: string
          is_default?: boolean
          name: string
          updated_at?: string
          user_id: string
        }
        Update: {
          avatar_url?: string | null
          context_type?: string | null
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          emoji?: string | null
          id?: string
          is_default?: boolean
          name?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      recommendation_items: {
        Row: {
          created_at: string
          id: string
          match_score: number | null
          openai_reason: string | null
          rank_index: number
          session_id: string
          title_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          match_score?: number | null
          openai_reason?: string | null
          rank_index: number
          session_id: string
          title_id: string
        }
        Update: {
          created_at?: string
          id?: string
          match_score?: number | null
          openai_reason?: string | null
          rank_index?: number
          session_id?: string
          title_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recommendation_items_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "recommendation_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recommendation_items_title_id_fkey"
            columns: ["title_id"]
            isOneToOne: false
            referencedRelation: "media_titles"
            referencedColumns: ["id"]
          },
        ]
      }
      recommendation_sessions: {
        Row: {
          created_at: string
          id: string
          input_payload: Json
          mood_label: string | null
          mood_tags: string[] | null
          openai_response: Json | null
          profile_id: string
          session_type: Database["public"]["Enums"]["recommendation_session_type"]
          top_title_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          input_payload?: Json
          mood_label?: string | null
          mood_tags?: string[] | null
          openai_response?: Json | null
          profile_id: string
          session_type: Database["public"]["Enums"]["recommendation_session_type"]
          top_title_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          input_payload?: Json
          mood_label?: string | null
          mood_tags?: string[] | null
          openai_response?: Json | null
          profile_id?: string
          session_type?: Database["public"]["Enums"]["recommendation_session_type"]
          top_title_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "recommendation_sessions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recommendation_sessions_top_title_id_fkey"
            columns: ["top_title_id"]
            isOneToOne: false
            referencedRelation: "media_titles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      get_profile_home_data: { Args: { p_profile_id: string }; Returns: Json }
    }
    Enums: {
      interaction_action:
        | "impression"
        | "open"
        | "play"
        | "complete"
        | "like"
        | "dislike"
        | "skip"
        | "feedback"
      recommendation_session_type: "onboarding" | "mood" | "quick_match"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      interaction_action: [
        "impression",
        "open",
        "play",
        "complete",
        "like",
        "dislike",
        "skip",
        "feedback",
      ],
      recommendation_session_type: ["onboarding", "mood", "quick_match"],
    },
  },
} as const

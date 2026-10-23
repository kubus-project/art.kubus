jsonb_build_object(
    -- Public mappers expose marker_data/config, so keep every public key
    -- change-sensitive and remove only the enumerated engagement/sync fields.
    'markerData', CASE
      WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'stats') = 'object'
      THEN CASE
        WHEN (am.marker_data -> 'stats') - array_remove(ARRAY[
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'viewCount') = 'number' THEN 'viewCount' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'view_count') = 'number' THEN 'view_count' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'interactionCount') = 'number' THEN 'interactionCount' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'interaction_count') = 'number' THEN 'interaction_count' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'activationCount') = 'number' THEN 'activationCount' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'activation_count') = 'number' THEN 'activation_count' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'lastActivated') = 'string'
                 AND (am.marker_data -> 'stats' ->> 'lastActivated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastActivated' END,
          CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'last_activated') = 'string'
                 AND (am.marker_data -> 'stats' ->> 'last_activated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_activated' END
        ]::text[], NULL::text) = '{}'::jsonb
          AND am.marker_data -> 'stats' <> '{}'::jsonb
        THEN COALESCE(am.marker_data, '{}'::jsonb) - 'stats'
        ELSE jsonb_set(
          COALESCE(am.marker_data, '{}'::jsonb),
          '{stats}',
          (am.marker_data -> 'stats') - array_remove(ARRAY[
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'viewCount') = 'number' THEN 'viewCount' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'view_count') = 'number' THEN 'view_count' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'interactionCount') = 'number' THEN 'interactionCount' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'interaction_count') = 'number' THEN 'interaction_count' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'activationCount') = 'number' THEN 'activationCount' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'activation_count') = 'number' THEN 'activation_count' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'lastActivated') = 'string'
                   AND (am.marker_data -> 'stats' ->> 'lastActivated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastActivated' END,
            CASE WHEN jsonb_typeof(am.marker_data -> 'stats' -> 'last_activated') = 'string'
                   AND (am.marker_data -> 'stats' ->> 'last_activated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_activated' END
          ]::text[], NULL::text),
          false
        )
      END
      ELSE COALESCE(am.marker_data, '{}'::jsonb)
    END - array_remove(ARRAY[
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'viewCount') = 'number' THEN 'viewCount' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'view_count') = 'number' THEN 'view_count' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'interactionCount') = 'number' THEN 'interactionCount' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'interaction_count') = 'number' THEN 'interaction_count' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'activationCount') = 'number' THEN 'activationCount' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'activation_count') = 'number' THEN 'activation_count' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'lastActivated') = 'string'
             AND (am.marker_data ->> 'lastActivated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastActivated' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'last_activated') = 'string'
             AND (am.marker_data ->> 'last_activated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_activated' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'createdAt') = 'string'
             AND (am.marker_data ->> 'createdAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'createdAt' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'created_at') = 'string'
             AND (am.marker_data ->> 'created_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'created_at' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'updatedAt') = 'string'
             AND (am.marker_data ->> 'updatedAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'updatedAt' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'updated_at') = 'string'
             AND (am.marker_data ->> 'updated_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'updated_at' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'syncStatus') = 'string' THEN 'syncStatus' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'sync_status') = 'string' THEN 'sync_status' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'lastSyncedAt') = 'string'
             AND (am.marker_data ->> 'lastSyncedAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastSyncedAt' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'last_synced_at') = 'string'
             AND (am.marker_data ->> 'last_synced_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_synced_at' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'orbitLastSyncedAt') = 'string'
             AND (am.marker_data ->> 'orbitLastSyncedAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'orbitLastSyncedAt' END,
      CASE WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'orbit_last_synced_at') = 'string'
             AND (am.marker_data ->> 'orbit_last_synced_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'orbit_last_synced_at' END
    ]::text[], NULL::text),
    'markerType', am.marker_type,
    'artworkId', am.artwork_id,
    'latitude', am.latitude,
    'longitude', am.longitude,
    'altitude', am.altitude,
    'activationRadius', am.activation_radius,
    'city', am.city,
    'country', am.country,
    'pose', jsonb_build_object(
      'position', jsonb_build_object('x', am.position_x, 'y', am.position_y, 'z', am.position_z),
      'rotation', jsonb_build_object('x', am.rotation_x, 'y', am.rotation_y, 'z', am.rotation_z),
      'scale', am.scale
    ),
    'ar', CASE WHEN arm.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', arm.id,
      'modelCID', arm.model_cid,
      'modelURL', arm.model_url,
      'storageProvider', arm.storage_provider,
      'config', (
        CASE
          WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'stats') = 'object'
          THEN CASE
            WHEN (arm.config -> 'stats') - array_remove(ARRAY[
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'viewCount') = 'number' THEN 'viewCount' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'view_count') = 'number' THEN 'view_count' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'interactionCount') = 'number' THEN 'interactionCount' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'interaction_count') = 'number' THEN 'interaction_count' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'activationCount') = 'number' THEN 'activationCount' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'activation_count') = 'number' THEN 'activation_count' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'lastActivated') = 'string'
                     AND (arm.config -> 'stats' ->> 'lastActivated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastActivated' END,
              CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'last_activated') = 'string'
                     AND (arm.config -> 'stats' ->> 'last_activated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_activated' END
            ]::text[], NULL::text) = '{}'::jsonb
              AND arm.config -> 'stats' <> '{}'::jsonb
            THEN COALESCE(arm.config, '{}'::jsonb) - 'stats'
            ELSE jsonb_set(
              COALESCE(arm.config, '{}'::jsonb),
              '{stats}',
              (arm.config -> 'stats') - array_remove(ARRAY[
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'viewCount') = 'number' THEN 'viewCount' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'view_count') = 'number' THEN 'view_count' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'interactionCount') = 'number' THEN 'interactionCount' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'interaction_count') = 'number' THEN 'interaction_count' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'activationCount') = 'number' THEN 'activationCount' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'activation_count') = 'number' THEN 'activation_count' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'lastActivated') = 'string'
                       AND (arm.config -> 'stats' ->> 'lastActivated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastActivated' END,
                CASE WHEN jsonb_typeof(arm.config -> 'stats' -> 'last_activated') = 'string'
                       AND (arm.config -> 'stats' ->> 'last_activated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_activated' END
              ]::text[], NULL::text),
              false
            )
          END
          ELSE COALESCE(arm.config, '{}'::jsonb)
        END
      ) - array_remove(ARRAY[
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'viewCount') = 'number' THEN 'viewCount' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'view_count') = 'number' THEN 'view_count' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'interactionCount') = 'number' THEN 'interactionCount' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'interaction_count') = 'number' THEN 'interaction_count' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'activationCount') = 'number' THEN 'activationCount' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'activation_count') = 'number' THEN 'activation_count' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'lastActivated') = 'string'
               AND (arm.config ->> 'lastActivated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastActivated' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'last_activated') = 'string'
               AND (arm.config ->> 'last_activated') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_activated' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'createdAt') = 'string'
               AND (arm.config ->> 'createdAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'createdAt' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'created_at') = 'string'
               AND (arm.config ->> 'created_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'created_at' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'updatedAt') = 'string'
               AND (arm.config ->> 'updatedAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'updatedAt' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'updated_at') = 'string'
               AND (arm.config ->> 'updated_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'updated_at' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'syncStatus') = 'string' THEN 'syncStatus' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'sync_status') = 'string' THEN 'sync_status' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'lastSyncedAt') = 'string'
               AND (arm.config ->> 'lastSyncedAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'lastSyncedAt' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'last_synced_at') = 'string'
               AND (arm.config ->> 'last_synced_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'last_synced_at' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'orbitLastSyncedAt') = 'string'
               AND (arm.config ->> 'orbitLastSyncedAt') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'orbitLastSyncedAt' END,
        CASE WHEN jsonb_typeof(COALESCE(arm.config, '{}'::jsonb) -> 'orbit_last_synced_at') = 'string'
               AND (arm.config ->> 'orbit_last_synced_at') ~ '^(?:[0-9]{4}-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12][0-9]|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12][0-9]|30)|02-(?:0[1-9]|1[0-9]|2[0-8]))|(?:[0-9]{2}(?:0[48]|[2468][048]|[13579][26])|(?:[02468][048]|[13579][26])00)-02-29)T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:[.][0-9]+)?(?:Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$' THEN 'orbit_last_synced_at' END
      ]::text[], NULL::text),
      'scale', arm.scale,
      'rotation', jsonb_build_object('x', arm.rotation_x, 'y', arm.rotation_y, 'z', arm.rotation_z),
      'enableAnimation', arm.enable_animation,
      'enableInteraction', arm.enable_interaction,
      'isActive', arm.is_active
    ) END,
    'linkedArtwork', CASE WHEN a.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', a.id,
      'title', a.title,
      'description', a.description,
      'artistName', a.artist_name,
      'imageUrl', a.image_url,
      'model3dUrl', a.model_3d_url,
      'model3dCid', a.model_3d_cid,
      'locationName', a.location_name,
      'isNft', a.is_nft
    ) END
  )
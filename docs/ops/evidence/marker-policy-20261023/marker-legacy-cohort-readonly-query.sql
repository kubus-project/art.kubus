WITH base AS (
  SELECT am.id, am.created_at, am.latitude, am.longitude, am.artwork_id,
         (jsonb_build_object(
    -- Public mappers expose marker_data/config, so keep every public key
    -- change-sensitive and remove only the enumerated engagement/sync fields.
    'markerData', CASE
      WHEN jsonb_typeof(COALESCE(am.marker_data, '{}'::jsonb) -> 'stats') = 'object'
      THEN CASE
        WHEN (am.marker_data -> 'stats') - ARRAY[
          'viewCount', 'view_count', 'interactionCount', 'interaction_count',
          'activationCount', 'activation_count', 'lastActivated', 'last_activated'
        ]::text[] = '{}'::jsonb
        THEN COALESCE(am.marker_data, '{}'::jsonb) - 'stats'
        ELSE jsonb_set(
          COALESCE(am.marker_data, '{}'::jsonb),
          '{stats}',
          (am.marker_data -> 'stats') - ARRAY[
            'viewCount', 'view_count', 'interactionCount', 'interaction_count',
            'activationCount', 'activation_count', 'lastActivated', 'last_activated'
          ]::text[],
          false
        )
      END
      ELSE COALESCE(am.marker_data, '{}'::jsonb)
    END - ARRAY[
      'viewCount', 'view_count', 'interactionCount', 'interaction_count',
      'activationCount', 'activation_count', 'lastActivated', 'last_activated',
      'createdAt', 'created_at', 'updatedAt', 'updated_at',
      'syncStatus', 'sync_status', 'lastSyncedAt', 'last_synced_at',
      'orbitLastSyncedAt', 'orbit_last_synced_at'
    ]::text[],
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
            WHEN (arm.config -> 'stats') - ARRAY[
              'viewCount', 'view_count', 'interactionCount', 'interaction_count',
              'activationCount', 'activation_count', 'lastActivated', 'last_activated'
            ]::text[] = '{}'::jsonb
            THEN COALESCE(arm.config, '{}'::jsonb) - 'stats'
            ELSE jsonb_set(
              COALESCE(arm.config, '{}'::jsonb),
              '{stats}',
              (arm.config -> 'stats') - ARRAY[
                'viewCount', 'view_count', 'interactionCount', 'interaction_count',
                'activationCount', 'activation_count', 'lastActivated', 'last_activated'
              ]::text[],
              false
            )
          END
          ELSE COALESCE(arm.config, '{}'::jsonb)
        END
      ) - ARRAY[
        'createdAt', 'created_at', 'updatedAt', 'updated_at',
        'syncStatus', 'sync_status', 'lastSyncedAt', 'last_synced_at',
        'orbitLastSyncedAt', 'orbit_last_synced_at'
      ]::text[],
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
  )) AS material_projection,
         arm.id AS ar_marker_id, a.id AS linked_artwork_id,
         a.is_public AS linked_artwork_is_public, a.is_active AS linked_artwork_is_active,
         a.editorial_state AS linked_artwork_editorial_state
    FROM public.art_markers am
    LEFT JOIN public.ar_markers arm ON arm.art_marker_id = am.id
    LEFT JOIN public.artworks a ON a.id = am.artwork_id
   WHERE am.editorial_state = 'unreviewed'
     AND am.is_active IS TRUE
     AND COALESCE(lower(btrim(COALESCE(am.marker_data->>'isPublic', am.marker_data->>'is_public'))) IN ('true','1','yes','on'), true)
     AND COALESCE(lower(btrim(COALESCE(am.marker_data->>'isActive', am.marker_data->>'is_active'))) IN ('true','1','yes','on'), true)
), eligible AS (
  SELECT id, created_at,
         encode(sha256(convert_to(material_projection::text, 'UTF8')), 'hex') AS material_fingerprint
    FROM base
   WHERE latitude IS NOT NULL AND longitude IS NOT NULL
     AND (artwork_id IS NULL OR (
       linked_artwork_is_public IS TRUE
       AND COALESCE(linked_artwork_is_active, true) IS TRUE
       AND COALESCE(linked_artwork_editorial_state, 'unreviewed') NOT IN ('rejected', 'archived')
     ))
), frozen AS (
  SELECT id, material_fingerprint FROM eligible
   WHERE created_at <= '2026-10-22 23:31:10+00'::timestamptz
)
SELECT json_build_object(
  'counts', json_build_object(
    'raw_active_owner_public_unreviewed', (SELECT count(*) FROM base),
    'public_eligible_unreviewed', (SELECT count(*) FROM eligible),
    'eligible_by_cutoff', (SELECT count(*) FROM frozen),
    'eligible_after_cutoff_or_missing', (SELECT count(*) FROM eligible WHERE created_at > '2026-10-22 23:31:10+00'::timestamptz OR created_at IS NULL)
  ),
  'cohort', COALESCE((SELECT json_agg(json_build_object('marker_id', id::text, 'material_fingerprint', material_fingerprint) ORDER BY id::text) FROM frozen), '[]'::json)
) AS snapshot
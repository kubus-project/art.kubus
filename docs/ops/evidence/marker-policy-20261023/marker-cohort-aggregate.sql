-- One aggregate-only read against Oracle production. No ids, names, wallets, coordinates, URLs, or raw JSON are selected.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '60s';
SET LOCAL lock_timeout = '2s';
WITH raw AS (
  SELECT
    m.is_active,
    m.artwork_id,
    m.latitude IS NOT NULL AND m.longitude IS NOT NULL AS has_coordinates,
    lower(btrim(COALESCE(m.marker_data->>'isPublic', m.marker_data->>'is_public', 'true'))) AS visibility_text,
    to_jsonb(m)->>'editorial_state' AS editorial_state,
    a.id IS NOT NULL AS artwork_exists,
    a.is_public AS artwork_is_public,
    COALESCE(a.is_active, true) AS artwork_is_active,
    COALESCE(a.is_nft, false) AS artwork_is_nft,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,source}', m.marker_data->>'source')), '') AS source_name,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,sourceId}', m.marker_data->>'sourceId')), '') AS source_id,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,osmId}', m.marker_data->>'osmId')), '') AS osm_id,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,wikidataId}', m.marker_data->>'wikidataId')), '') AS wikidata_id,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,commonsFile}', m.marker_data->>'commonsFile')), '') AS commons_file,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,europeanaId}', m.marker_data->>'europeanaId')), '') AS europeana_id,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,sourceUrl}', m.marker_data->>'sourceUrl')), '') AS source_url,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,sourceLicense}', m.marker_data->>'sourceLicense', m.marker_data#>>'{metadata,imageLicense}', m.marker_data->>'imageLicense')), '') AS license_ref,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,artistName}', m.marker_data#>>'{metadata,artist}', m.marker_data->>'artistName', m.marker_data->>'artist')), '') AS artist_field,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,imageAuthor}', m.marker_data#>>'{metadata,coverImageAttribution}', m.marker_data->>'imageAuthor')), '') AS image_credit_field,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,coverImageUrl}', m.marker_data#>>'{metadata,imageUrl}', m.marker_data->>'imageUrl', m.marker_data->>'image_url')), '') AS image_ref,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,description}', m.marker_data->>'description')), '') AS description_text,
    NULLIF(btrim(COALESCE(m.marker_data#>>'{metadata,locationName}', m.marker_data#>>'{metadata,placeName}', m.marker_data->>'locationName', m.marker_data->>'placeName')), '') AS place_label
  FROM art_markers m
  LEFT JOIN artworks a ON a.id = m.artwork_id
), legacy AS (
  SELECT *,
    CASE
      WHEN artwork_id IS NULL THEN 'independent'
      ELSE 'linked_public_artwork'
    END AS linkage,
    CASE
      WHEN lower(COALESCE(source_name, '')) ~ 'openstreetmap|(^|[^a-z])osm([^a-z]|$)' OR osm_id IS NOT NULL THEN 'openstreetmap'
      WHEN lower(COALESCE(source_name, '')) ~ 'wikidata' OR wikidata_id IS NOT NULL THEN 'wikidata'
      WHEN lower(COALESCE(source_name, '')) ~ 'commons|wikimedia' OR commons_file IS NOT NULL THEN 'wikimedia_commons'
      WHEN lower(COALESCE(source_name, '')) ~ 'user|community|manual' THEN 'user_or_community_label'
      WHEN source_name IS NOT NULL OR source_id IS NOT NULL OR source_url IS NOT NULL OR europeana_id IS NOT NULL THEN 'other_named_or_provider'
      ELSE 'unknown'
    END AS source_family
  FROM raw
  WHERE is_active IS TRUE
    AND visibility_text <> 'false'
    AND (artwork_id IS NULL OR (artwork_exists AND artwork_is_public IS TRUE AND artwork_is_active IS TRUE))
), recognized AS (
  SELECT * FROM legacy WHERE visibility_text IN ('true', '1', 'yes')
), metrics AS (
  SELECT 'count'::text AS family, 'legacy_active_public_and_link_visible'::text AS name, count(*)::bigint AS value FROM legacy
  UNION ALL SELECT 'count', 'recognized_true_1_yes_variant', count(*) FROM recognized
  UNION ALL SELECT 'count', 'strict_approved_under_candidate_predicate', count(*) FROM recognized WHERE editorial_state = 'approved'
  UNION ALL SELECT 'count', 'strict_would_exclude_unreviewed', count(*) FROM recognized WHERE editorial_state = 'unreviewed'
  UNION ALL SELECT 'count', 'strict_would_exclude_other_or_missing_review_state', count(*) FROM recognized WHERE editorial_state IS DISTINCT FROM 'approved' AND editorial_state IS DISTINCT FROM 'unreviewed'
  UNION ALL SELECT 'review_state', COALESCE(editorial_state, '(missing)'), count(*) FROM legacy GROUP BY 2
  UNION ALL SELECT 'linkage', linkage, count(*) FROM legacy GROUP BY 2
  UNION ALL SELECT 'linked_artwork_kind', CASE WHEN artwork_is_nft THEN 'collectible' ELSE 'non_collectible' END, count(*) FROM legacy WHERE artwork_id IS NOT NULL GROUP BY 2
  UNION ALL SELECT 'source_family', source_family, count(*) FROM legacy GROUP BY 2
  UNION ALL SELECT 'completeness', 'coordinates_present', count(*) FROM legacy WHERE has_coordinates
  UNION ALL SELECT 'completeness', 'external_source_id_or_url_present', count(*) FROM legacy WHERE source_id IS NOT NULL OR osm_id IS NOT NULL OR wikidata_id IS NOT NULL OR commons_file IS NOT NULL OR europeana_id IS NOT NULL OR source_url IS NOT NULL
  UNION ALL SELECT 'completeness', 'license_or_image_license_field_present', count(*) FROM legacy WHERE license_ref IS NOT NULL
  UNION ALL SELECT 'completeness', 'artist_or_creator_text_field_present', count(*) FROM legacy WHERE artist_field IS NOT NULL
  UNION ALL SELECT 'completeness', 'image_credit_text_field_present', count(*) FROM legacy WHERE image_credit_field IS NOT NULL
  UNION ALL SELECT 'completeness', 'image_reference_present', count(*) FROM legacy WHERE image_ref IS NOT NULL
  UNION ALL SELECT 'completeness', 'description_present', count(*) FROM legacy WHERE description_text IS NOT NULL
  UNION ALL SELECT 'completeness', 'place_label_present', count(*) FROM legacy WHERE place_label IS NOT NULL
)
SELECT 'measurement'::text AS family, 'utc'::text AS name, to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS value
UNION ALL SELECT family, name, value::text FROM metrics
ORDER BY family, name;
COMMIT;

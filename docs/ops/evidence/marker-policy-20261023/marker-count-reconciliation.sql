-- One bounded aggregate reconciliation against the Oracle primary. No marker IDs,
-- user names, wallets, coordinates, URLs, or raw marker JSON are selected.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '60s';
SET LOCAL lock_timeout = '2s';
WITH raw AS (
  SELECT
    m.is_active,
    m.artwork_id IS NOT NULL AS is_linked,
    to_jsonb(m)->>'editorial_state' AS editorial_state,
    COALESCE((m.marker_data->>'isPublic')::boolean,
             (m.marker_data->>'is_public')::boolean, true) AS public_cast,
    lower(COALESCE(m.marker_data->>'isPublic', m.marker_data->>'is_public', 'true')) AS public_text,
    m.latitude IS NOT NULL AND m.longitude IS NOT NULL AS has_coordinates,
    a.id IS NOT NULL AS artwork_exists,
    COALESCE(a.is_public, false) AS artwork_public,
    COALESCE(a.is_active, true) AS artwork_active,
    COALESCE(a.is_nft, false) AS artwork_is_collectible,
    COALESCE(NULLIF(btrim(m.marker_data->>'title'), ''),
             NULLIF(btrim(m.marker_data->>'name'), '')) IS NOT NULL AS has_title,
    length(btrim(COALESCE(m.marker_data#>>'{metadata,description}', m.marker_data->>'description', ''))) >= 80 AS description_80,
    COALESCE(m.marker_data#>>'{metadata,sourceUrl}', m.marker_data->>'sourceUrl', '') ~ '^https://[^[:space:]/]+\.[^[:space:]]+' AS has_source_url,
    COALESCE(m.marker_data#>>'{metadata,wikidataId}', m.marker_data->>'wikidataId', '') ~ '^Q[1-9][0-9]*$' AS has_wikidata_id,
    COALESCE(m.marker_data#>>'{metadata,osmId}', m.marker_data->>'osmId', '') ~ '^[1-9][0-9]*$' AS has_osm_id
  FROM art_markers m
  LEFT JOIN artworks a ON a.id = m.artwork_id
), metrics AS (
  -- Exact grouping from the preserved saved proof SELECT (the query file has no output artifact).
  SELECT 'saved_proof_group'::text AS family,
         COALESCE(editorial_state, '(missing)') || ' | active=' || COALESCE(is_active::text, '(null)') ||
         ' | own_public=' || COALESCE(public_cast::text, '(null)') AS name,
         count(*)::bigint AS value
  FROM raw GROUP BY editorial_state, is_active, public_cast

  UNION ALL SELECT 'predicate_total', 'all_marker_rows', count(*) FROM raw
  UNION ALL SELECT 'predicate_total', 'saved_proof_active_and_own_public_cast_true', count(*)
    FROM raw WHERE is_active IS TRUE AND public_cast IS TRUE
  UNION ALL SELECT 'predicate_total', 'old_map_API_exact_cast_active_coords_link_owner_visible', count(*)
    FROM raw WHERE is_active IS TRUE AND public_cast IS TRUE AND has_coordinates
      AND (NOT is_linked OR (artwork_exists AND artwork_public IS TRUE AND artwork_active IS TRUE))
  UNION ALL SELECT 'predicate_total', 'SEO_repository_legacy_text_active_link_owner_visible', count(*)
    FROM raw WHERE is_active IS TRUE AND public_text IN ('true', '1', 'yes')
      AND (NOT is_linked OR (artwork_exists AND artwork_public IS TRUE AND artwork_active IS TRUE))
  UNION ALL SELECT 'predicate_total', 'resume_aggregate_active_non_false_link_owner_visible', count(*)
    FROM raw WHERE is_active IS TRUE AND public_text <> 'false'
      AND (NOT is_linked OR (artwork_exists AND artwork_public IS TRUE AND artwork_active IS TRUE))
  UNION ALL SELECT 'predicate_total', 'WIP_strict_candidate_SQL_approved_active_text_link_owner_visible', count(*)
    FROM raw WHERE editorial_state = 'approved' AND is_active IS TRUE
      AND public_text IN ('true', '1', 'yes')
      AND (NOT is_linked OR (artwork_exists AND artwork_public IS TRUE AND artwork_active IS TRUE))

  UNION ALL SELECT 'saved_proof_public_breakdown',
         'link=' || CASE WHEN is_linked THEN 'linked' ELSE 'independent' END ||
         '|artwork=' || CASE WHEN NOT is_linked THEN 'n/a' WHEN NOT artwork_exists THEN 'missing'
           WHEN NOT artwork_public OR NOT artwork_active THEN 'not_public_active'
           WHEN artwork_is_collectible THEN 'collectible' ELSE 'non_collectible' END ||
         '|state=' || COALESCE(editorial_state, '(missing)'), count(*)
    FROM raw WHERE is_active IS TRUE AND public_cast IS TRUE
    GROUP BY 2

  UNION ALL SELECT 'legacy_map_breakdown',
         'link=' || CASE WHEN is_linked THEN 'linked' ELSE 'independent' END ||
         '|artwork=' || CASE WHEN NOT is_linked THEN 'n/a' WHEN NOT artwork_exists THEN 'missing'
           WHEN NOT artwork_public OR NOT artwork_active THEN 'not_public_active'
           WHEN artwork_is_collectible THEN 'collectible' ELSE 'non_collectible' END ||
         '|state=' || COALESCE(editorial_state, '(missing)'), count(*)
    FROM raw WHERE is_active IS TRUE AND public_text IN ('true', '1', 'yes') AND has_coordinates
      AND (NOT is_linked OR (artwork_exists AND artwork_public IS TRUE AND artwork_active IS TRUE))
    GROUP BY 2

  UNION ALL SELECT 'seo_policy', 'linked_marker_route_policy_v1_2_candidates_canonical_to_artwork_not_sitemap', count(*)
    FROM raw WHERE is_active IS TRUE AND public_text IN ('true', '1', 'yes') AND is_linked
      AND artwork_exists AND artwork_public IS TRUE AND artwork_active IS TRUE
  UNION ALL SELECT 'seo_policy', 'independent_cultural_marker_pages_approved_and_substantive', count(*)
    FROM raw WHERE NOT is_linked AND editorial_state = 'approved' AND is_active IS TRUE
      AND public_text IN ('true', '1', 'yes') AND has_coordinates AND has_title
      AND (description_80 OR (has_source_url AND (has_wikidata_id OR has_osm_id)))
)
SELECT 'measurement'::text AS family, 'utc'::text AS name,
       to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS value
UNION ALL SELECT family, name, value::text FROM metrics
ORDER BY family, name;
COMMIT;

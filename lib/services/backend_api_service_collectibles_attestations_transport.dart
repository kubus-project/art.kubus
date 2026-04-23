part of 'backend_api_service.dart';

// Collectibles and attestation transport covers achievements, attendance,
// POAP, and collection-adjacent backend calls. Local NFT minting remains
// local-first and is not backend transport.

class BackendAttestationTaxonomyDto {
	const BackendAttestationTaxonomyDto({
		required this.version,
		required this.attestationTypes,
		required this.usageSurfaces,
		required this.uiOnlyAchievementCodes,
		required this.optionalMintingForScarcity,
	});

	final String version;
	final List<String> attestationTypes;
	final List<String> usageSurfaces;
	final List<String> uiOnlyAchievementCodes;
	final bool optionalMintingForScarcity;

	factory BackendAttestationTaxonomyDto.fromJson(Map<String, dynamic> json) {
		List<String> parseList(dynamic raw) {
			if (raw is! List) return const <String>[];
			return raw.map((item) => item.toString()).toList(growable: false);
		}

		final mintPolicy =
				json['mintPolicy'] is Map ? Map<String, dynamic>.from(json['mintPolicy'] as Map) : const <String, dynamic>{};

		return BackendAttestationTaxonomyDto(
			version: (json['version'] ?? '1.0').toString(),
			attestationTypes: parseList(json['attestationTypes']),
			usageSurfaces: parseList(json['usageSurfaces']),
			uiOnlyAchievementCodes: parseList(json['uiOnlyAchievementCodes']),
			optionalMintingForScarcity:
					mintPolicy['optionalWhenScarcityOrOwnershipMatters'] == true,
		);
	}
}

Future<BackendAttestationTaxonomyDto?> _backendApiGetAttestationTaxonomy(
	BackendApiService service,
) async {
	try {
		final uri = Uri.parse('${service.baseUrl}/api/attestations/taxonomy');
		final response = await service._get(
			uri,
			headers: service._getHeaders(includeAuth: false),
			includeAuth: false,
		);
		if (response.statusCode != 200) return null;
		final decoded = jsonDecode(response.body) as Map<String, dynamic>;
		final payload = decoded['data'] ?? decoded;
		if (payload is! Map<String, dynamic>) return null;
		final taxonomyRaw = payload['taxonomy'];
		if (taxonomyRaw is! Map<String, dynamic>) return null;
		return BackendAttestationTaxonomyDto.fromJson(taxonomyRaw);
	} catch (_) {
		return null;
	}
}

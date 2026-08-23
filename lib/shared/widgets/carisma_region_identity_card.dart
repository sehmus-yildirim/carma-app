import 'package:flutter/material.dart';

import '../plate/dach_plate_presentation.dart';
import '../theme/carisma_design_tokens.dart';
import 'glass_card.dart';

class CaRismaRegionIdentityCard extends StatelessWidget {
  const CaRismaRegionIdentityCard({
    super.key,
    required this.region,
    this.onTap,
    this.showOuterEffects = true,
  });

  final RegistrationRegionPresentationData region;
  final VoidCallback? onTap;
  final bool showOuterEffects;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 20,
      showOuterEffects: showOuterEffects,
      child: Semantics(
        button: onTap != null,
        label: region.displayName,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: CaRismaDesignTokens.surface2.withValues(
                        alpha: 0.9,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      child: _RegionEmblem(
                        key: ValueKey(region.regionCoatAsset),
                        region: region,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      region.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.08,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.52),
                    size: 23,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionEmblem extends StatelessWidget {
  const _RegionEmblem({super.key, required this.region});

  final RegistrationRegionPresentationData region;

  @override
  Widget build(BuildContext context) {
    if (region.usesFallback) {
      return const _NeutralEmblem();
    }
    return Image.asset(
      region.regionCoatAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const _NeutralEmblem(),
    );
  }
}

class _NeutralEmblem extends StatelessWidget {
  const _NeutralEmblem();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.shield_outlined,
      color: CaRismaDesignTokens.textMuted,
      size: 34,
    );
  }
}

Future<RegistrationRegionPresentationData?> showCaRismaRegistrationRegionPicker(
  BuildContext context, {
  required String countryCode,
}) {
  return showModalBottomSheet<RegistrationRegionPresentationData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _CaRismaRegistrationRegionPickerSheet(
      countryCode: countryCode,
      regions: registrationRegionsForCountry(countryCode),
    ),
  );
}

class _CaRismaRegistrationRegionPickerSheet extends StatefulWidget {
  const _CaRismaRegistrationRegionPickerSheet({
    required this.countryCode,
    required this.regions,
  });

  final String countryCode;
  final List<RegistrationRegionPresentationData> regions;

  @override
  State<_CaRismaRegistrationRegionPickerSheet> createState() =>
      _CaRismaRegistrationRegionPickerSheetState();
}

class _CaRismaRegistrationRegionPickerSheetState
    extends State<_CaRismaRegistrationRegionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegistrationRegionPresentationData> get _visibleRegions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.regions;
    }
    return widget.regions
        .where((region) {
          return region.plateCode.toLowerCase().contains(query) ||
              region.displayName.toLowerCase().contains(query) ||
              region.parentRegionName.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final regions = _visibleRegions;
    final country = countryPresentationFor(widget.countryCode);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zulassungsregion wählen',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          country.label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    tooltip: 'Schließen',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Code oder Stadt suchen',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                  filled: true,
                  fillColor: CaRismaDesignTokens.controlSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: CaRismaDesignTokens.blueBright,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: regions.isEmpty
                  ? Center(
                      child: Text(
                        'Keine passende Zulassungsregion gefunden.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: CaRismaDesignTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 22),
                      itemCount: regions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.065),
                      ),
                      itemBuilder: (context, index) {
                        final region = regions[index];
                        return Semantics(
                          button: true,
                          label: '${region.plateCode}, ${region.displayName}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(region),
                            child: Container(
                              decoration: BoxDecoration(
                                color: CaRismaDesignTokens.controlSurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      region.plateCode,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: CaRismaDesignTokens.bluePrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: region.usesFallback
                                        ? const Icon(
                                            Icons.shield_outlined,
                                            color:
                                                CaRismaDesignTokens.textMuted,
                                          )
                                        : Image.asset(
                                            region.regionCoatAsset,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.shield_outlined,
                                                  color: CaRismaDesignTokens
                                                      .textMuted,
                                                ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          region.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          region.parentRegionName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: CaRismaDesignTokens
                                                .textSecondary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:eq_trainer/theme_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

class ConfigCard extends StatelessWidget {
  const ConfigCard({
    super.key,
    required this.cardType,
  });
  final ConfigCardType cardType;

  @override
  Widget build(BuildContext context) {
    // Select only the field relevant to this card so other cards don't rebuild.
    final currentValue = context.select<SessionParameter, Object?>((p) {
      switch (cardType) {
        case ConfigCardType.startingBand: return p.startingBand;
        case ConfigCardType.gain:         return p.gain;
        case ConfigCardType.qFactor:      return p.qFactor;
        case ConfigCardType.filterType:   return p.filterType;
        case ConfigCardType.threshold:    return p.threshold;
      }
    });
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: colors.surfaceContainer,
        child: ListTile(
          minVerticalPadding: 12,
          contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          title: Text(
            cardType.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            cardType.subtitle,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant,
            ),
          ),
          trailing: DropdownButton(
            alignment: Alignment.centerRight,
            isDense: true,
            value: currentValue,
            menuMaxHeight: MediaQuery.sizeOf(context).height * kCardDropDownMenuHeight,
            items: (cardType == ConfigCardType.startingBand || cardType == ConfigCardType.gain || cardType == ConfigCardType.threshold)
                ? cardType.valueList.map<DropdownMenuItem<int>>((item) {
                    return DropdownMenuItem<int>(
                      value: item,
                      child: Text(item.toString()),
                    );
                  }).toList()
                : (cardType == ConfigCardType.qFactor)
                    ? cardType.valueList.map<DropdownMenuItem<double>>((dynamic item) {
                        return DropdownMenuItem<double>(
                          value: item,
                          child: Text(item.toString()),
                        );
                      }).toList()
                    : (cardType == ConfigCardType.filterType)
                        ? cardType.valueList.map<DropdownMenuItem<FilterType>>((item) {
                            return DropdownMenuItem<FilterType>(
                              value: item,
                              child: switch (item as FilterType) {
                                FilterType.peak    => Text("CONFIG_CARD_DDB_FT_P".tr()),
                                FilterType.dip     => Text("CONFIG_CARD_DDB_FT_D".tr()),
                                FilterType.peakDip => Text("CONFIG_CARD_DDB_FT_PD".tr()),
                              },
                            );
                          }).toList()
                        : null,
            onChanged: (dynamic value) {
              final session = context.read<SessionParameter>();
              switch (cardType) {
                case ConfigCardType.startingBand: session.startingBand = value as int; break;
                case ConfigCardType.gain:         session.gain = value as int; break;
                case ConfigCardType.qFactor:      session.qFactor = value as double; break;
                case ConfigCardType.filterType:   session.filterType = value as FilterType; break;
                case ConfigCardType.threshold:    session.threshold = value as int; break;
              }
            },
          ),
        ),
      ),
    );
  }
}

enum ConfigCardType { 
  startingBand, gain, qFactor, filterType, threshold;
  
  String get title {
    switch(this) {
      case ConfigCardType.startingBand: return "CONFIG_CARD_TITLE_SB".tr();
      case ConfigCardType.gain: return "CONFIG_CARD_TITLE_G".tr();
      case ConfigCardType.qFactor: return "CONFIG_CARD_TITLE_QF".tr();
      case ConfigCardType.filterType: return "CONFIG_CARD_TITLE_FT".tr();
      case ConfigCardType.threshold: return "CONFIG_CARD_TITLE_T".tr();
    }
  }
  String get subtitle {
    switch(this) {
      case ConfigCardType.startingBand: return "CONFIG_CARD_SUBTITLE_SB".tr();
      case ConfigCardType.gain: return "CONFIG_CARD_SUBTITLE_G".tr();
      case ConfigCardType.qFactor: return "CONFIG_CARD_SUBTITLE_QF".tr();
      case ConfigCardType.filterType: return "CONFIG_CARD_SUBTITLE_FT".tr();
      case ConfigCardType.threshold: return "CONFIG_CARD_SUBTITLE_T".tr();
    }
  }
  List<dynamic> get valueList {
    switch(this) {
      case ConfigCardType.startingBand: return [for(var i = 2; i <= 25; i+=1) i];
      case ConfigCardType.gain: return [3,4,5,6,8,10,15];
      case ConfigCardType.qFactor: return [0.1, 0.5, 1.0, 2.0, 5.0, 10.0];
      case ConfigCardType.filterType: return [FilterType.peak, FilterType.dip, FilterType.peakDip];
      case ConfigCardType.threshold: return [1, 3, 5, 10];
    }
  }
}
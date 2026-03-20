import 'package:eq_trainer/theme_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/index.dart';

class ConfigCard extends StatelessWidget {
  const ConfigCard({
    super.key,
    required this.cardType,
  });
  final ConfigCardType cardType;

  @override
  Widget build(BuildContext context) {
    final sessionValue = context.watch<SessionParameter>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: ListTile(
          minVerticalPadding: 12,
          contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          title: Text(
            cardType.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            cardType.subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: DropdownButton(
            alignment: Alignment.centerRight,
            isDense: true,
            value: (cardType == ConfigCardType.startingBand) ? sessionValue.startingBand
                :  (cardType == ConfigCardType.gain) ? sessionValue.gain
                :  (cardType == ConfigCardType.qFactor) ? sessionValue.qFactor
                :  (cardType == ConfigCardType.filterType) ? sessionValue.filterType
                :  (cardType == ConfigCardType.threshold) ? sessionValue.threshold
                :  null,
            menuMaxHeight: MediaQuery.of(context).size.height * kCardDropDownMenuHeight,
            items: (cardType == ConfigCardType.startingBand || cardType == ConfigCardType.gain || cardType == ConfigCardType.threshold) ?
                      cardType.valueList.map<DropdownMenuItem<int>>((item) {
                        return DropdownMenuItem<int>(
                          value: item,
                          child: Text(item.toString()),
                        );
                      }).toList()
                :  (cardType == ConfigCardType.qFactor) ?
                      cardType.valueList.map<DropdownMenuItem<double>>((dynamic item) {
                        return DropdownMenuItem<double>(
                          value: item,
                          child: Text(item.toString()),
                        );
                      }).toList()
                :  (cardType == ConfigCardType.filterType) ?
                      cardType.valueList.map<DropdownMenuItem<FilterType>>((item) {
                        return DropdownMenuItem<FilterType>(
                          value: item,
                          child: (item == FilterType.peak) ? Text("CONFIG_CARD_DDB_FT_P".tr())
                              :  (item == FilterType.dip) ? Text("CONFIG_CARD_DDB_FT_D".tr())
                              :  (item == FilterType.peakDip) ? Text("CONFIG_CARD_DDB_FT_PD".tr())
                              :  const Text("?"),
                        );
                      }).toList()
                :  null,
            onChanged: (dynamic value) {
              switch(cardType) {
                case ConfigCardType.startingBand: sessionValue.startingBand = value; break;
                case ConfigCardType.gain: sessionValue.gain = value; break;
                case ConfigCardType.qFactor: sessionValue.qFactor = value; break;
                case ConfigCardType.filterType: sessionValue.filterType = value; break;
                case ConfigCardType.threshold: sessionValue.threshold = value; break;
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
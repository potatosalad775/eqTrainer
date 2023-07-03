import 'package:eq_trainer/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/model/session_data.dart';

class ConfigCard extends StatefulWidget {
  final ConfigCardType cardType;
  const ConfigCard({Key? key, required this.cardType}) : super(key: key);

  @override
  State<ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<ConfigCard> {
  @override
  Widget build(BuildContext context) {
    final sessionValue = context.watch<SessionData>();
    final configCardInfo = ConfigCardInfo(type: widget.cardType);

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
          title: Text(configCardInfo.title),
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          subtitle: Text(configCardInfo.subtitle),
          subtitleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          trailing: DropdownButton(
            alignment: Alignment.centerRight,
            isDense: true,
            value: (widget.cardType == ConfigCardType.startingBand) ? sessionValue.startingBand
                :  (widget.cardType == ConfigCardType.gain) ? sessionValue.gain
                :  (widget.cardType == ConfigCardType.qFactor) ? sessionValue.qFactor
                :  (widget.cardType == ConfigCardType.filterType) ? sessionValue.filterType
                :  (widget.cardType == ConfigCardType.threshold) ? sessionValue.threshold
                :  null,
            menuMaxHeight: MediaQuery.of(context).size.height * reactiveElementData.cardDropDownMenuHeight,
            items: (widget.cardType == ConfigCardType.startingBand || widget.cardType == ConfigCardType.gain || widget.cardType == ConfigCardType.threshold) ?
                      configCardInfo.valueList.map<DropdownMenuItem<int>>((item) {
                        return DropdownMenuItem<int>(
                          value: item,
                          child: Text(item.toString()),
                        );
                      }).toList()
                :  (widget.cardType == ConfigCardType.qFactor) ?
                      configCardInfo.valueList.map<DropdownMenuItem<double>>((double item) {
                        return DropdownMenuItem<double>(
                          value: item,
                          child: Text(item.toString()),
                        );
                      }).toList()
                :  (widget.cardType == ConfigCardType.filterType) ?
                      configCardInfo.valueList.map<DropdownMenuItem<FilterType>>((item) {
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
              switch(widget.cardType) {
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

class ConfigCardInfo {
  final ConfigCardType type;

  ConfigCardInfo({
    required this.type,
  });

  get title {
    if(type == ConfigCardType.startingBand) { return "CONFIG_CARD_TITLE_SB".tr(); }
    else if(type == ConfigCardType.gain) { return "CONFIG_CARD_TITLE_G".tr(); }
    else if(type == ConfigCardType.qFactor) { return "CONFIG_CARD_TITLE_QF".tr(); }
    else if(type == ConfigCardType.filterType) { return "CONFIG_CARD_TITLE_FT".tr(); }
    else if(type == ConfigCardType.threshold) { return "CONFIG_CARD_TITLE_T".tr(); }
    else { return "?"; }
  }
  get subtitle {
    if(type == ConfigCardType.startingBand) { return "CONFIG_CARD_SUBTITLE_SB".tr(); }
    else if(type == ConfigCardType.gain) { return "CONFIG_CARD_SUBTITLE_G".tr(); }
    else if(type == ConfigCardType.qFactor) { return "CONFIG_CARD_SUBTITLE_QF".tr(); }
    else if(type == ConfigCardType.filterType) { return "CONFIG_CARD_SUBTITLE_FT".tr(); }
    else if(type == ConfigCardType.threshold) { return "CONFIG_CARD_SUBTITLE_T".tr(); }
    else { return "?"; }
  }
  get valueList {
    if(type == ConfigCardType.startingBand) { return [for(var i = 2; i <= 25; i+=1) i]; }
    else if(type == ConfigCardType.gain) { return [3,4,5,6,8,10,15]; }
    else if(type == ConfigCardType.qFactor) { return [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]; }
    else if(type == ConfigCardType.filterType) { return [FilterType.peak, FilterType.dip, FilterType.peakDip]; }
    else if(type == ConfigCardType.threshold) { return [1, 3, 5, 10]; }
    else { return "?"; }
  }
}

enum ConfigCardType { startingBand, gain, qFactor, filterType, threshold }
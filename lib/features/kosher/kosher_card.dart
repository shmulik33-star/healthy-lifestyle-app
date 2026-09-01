import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';

class KosherCard extends StatelessWidget {
  const KosherCard({super.key});

  String _hhmm(DateTime value) =>
      '${value.hour.toString().padLeft(2,'0')}:${value.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final state=AppStateScope.of(context);

    if(!state.kosherEnabled){
      return const Card(
        child:Padding(
          padding:EdgeInsets.all(16),
          child:Row(
            children:[
              Icon(Icons.tune),
              SizedBox(width:10),
              Expanded(child:Text('כשרות: לא הופעלה בפרופיל.')),
            ],
          ),
        ),
      );
    }

    if(!state.meatDairySeparationEnabled || state.meatWaitMinutes<=0){
      return const Card(
        child:Padding(
          padding:EdgeInsets.all(16),
          child:Row(
            children:[
              Icon(Icons.verified_outlined,color:AppTheme.mint),
              SizedBox(width:10),
              Expanded(child:Text('כשרות פעילה. לא הוגדר טיימר המתנה מבשר לחלב.')),
            ],
          ),
        ),
      );
    }

    final last=state.lastMeatTime;
    final allowed=state.dairyAllowedAt;
    if(last==null || state.dairyAllowed){
      return const Card(
        child:Padding(
          padding:EdgeInsets.all(16),
          child:Row(
            children:[
              Icon(Icons.verified_outlined,color:AppTheme.mint),
              SizedBox(width:10),
              Expanded(child:Text('מצב כשרות: אין כרגע המתנה פעילה מבשר לחלב.')),
            ],
          ),
        ),
      );
    }

    return Card(
      color:AppTheme.softMint,
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Row(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('🥩',style:TextStyle(fontSize:28)),
            const SizedBox(width:12),
            Expanded(
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  const Text('מצב כשרות: בשרי',style:TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:4),
                  Text(
                    'אכלת בשרי בשעה ${_hhmm(last)}. '
                    'לפי זמן ההמתנה שבחרת בפרופיל, חלבי יתאפשר בשעה ${_hhmm(allowed!)}.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

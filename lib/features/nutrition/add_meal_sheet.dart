import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';

class AddMealSheet extends StatefulWidget{
  const AddMealSheet({super.key});
  @override State<AddMealSheet> createState()=>_AddMealSheetState();
}

class _AddMealSheetState extends State<AddMealSheet>{
  FoodItem? food;
  double quantity=1;
  String? unit;

  @override
  Widget build(BuildContext context){
    final state=AppStateScope.of(context);
    final foods=state.allFoods;
    food ??= foods.first;
    unit ??= food!.units.keys.first;
    final current=food!;
    final currentUnit=unit!;
    final cal=current.caloriesFor(currentUnit,quantity);
    final p=current.proteinFor(currentUnit,quantity);

    return Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.of(context).viewInsets.bottom),
      child:SafeArea(
        child:SingleChildScrollView(
          padding:const EdgeInsets.all(20),
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('אכלתי',style:Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height:6),
              const Text('בחר מה אכלת עכשיו. מזון חדש מוסיפים בנפרד ל“מאגר המזונות”.'),
              const SizedBox(height:14),
              DropdownButtonFormField<FoodItem>(
                value:current,
                isExpanded:true,
                decoration:const InputDecoration(labelText:'בחר מזון',border:OutlineInputBorder()),
                items:foods.map((f)=>DropdownMenuItem(
                  value:f,
                  child:Text('${f.name} · ${kosherStatusLabel(f.kosherStatus)}${f.kosherStatus==KosherStatus.kosher?' · ${kosherLabel(f.type)}':''}'),
                )).toList(),
                onChanged:(f){
                  if(f==null)return;
                  setState((){
                    food=f;unit=f.units.keys.first;quantity=1;
                  });
                },
              ),
              const SizedBox(height:14),
              Row(children:[
                Expanded(
                  child:DropdownButtonFormField<String>(
                    value:currentUnit,
                    decoration:const InputDecoration(labelText:'מידה',border:OutlineInputBorder()),
                    items:current.units.keys.map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),
                    onChanged:(v)=>setState(()=>unit=v),
                  ),
                ),
                const SizedBox(width:10),
                SizedBox(
                  width:135,
                  child:TextFormField(
                    initialValue:'1',
                    keyboardType:const TextInputType.numberWithOptions(decimal:true),
                    decoration:const InputDecoration(labelText:'כמות',border:OutlineInputBorder()),
                    onChanged:(v)=>setState(()=>quantity=double.tryParse(v.replaceAll(',','.'))??1),
                  ),
                ),
              ]),
              const SizedBox(height:14),
              Card(
                child:Padding(
                  padding:const EdgeInsets.all(16),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(current.name,style:const TextStyle(fontWeight:FontWeight.w800)),
                      Text('${kosherStatusLabel(current.kosherStatus)}${current.kosherStatus==KosherStatus.kosher?' · ${kosherLabel(current.type)}':''}'),
                      const SizedBox(height:6),
                      Text('כ־$cal קלוריות · ${p.toStringAsFixed(1)} גרם חלבון'),
                      Text('אומדן משקל: ${current.gramsFor(currentUnit,quantity).round()} גרם'),
                    ],
                  ),
                ),
              ),
              if(state.kosherEnabled && current.kosherStatus!=KosherStatus.kosher)...[
                const SizedBox(height:10),
                Card(
                  child:Padding(
                    padding:const EdgeInsets.all(12),
                    child:Text(
                      current.kosherStatus==KosherStatus.notKosher
                          ? 'שים לב: המזון מסומן כלא כשר. ניתן לתעד מה שנאכל בפועל, אך הוא לא יוצע אוטומטית.'
                          : 'שים לב: כשרות המזון אינה ידועה. ניתן לתעד מה שנאכל בפועל, אך הוא לא יוצע אוטומטית.',
                    ),
                  ),
                ),
              ],
              if(current.type==KosherFoodType.dairy&&!state.dairyAllowed)...[
                const SizedBox(height:10),
                Card(
                  child:Padding(
                    padding:const EdgeInsets.all(12),
                    child:Text(
                      'שים לב: לפי הגדרת הכשרות האישית שלך טרם הסתיימה ההמתנה מבשר לחלב. '
                      'אפשר לתעד מה שאכלת בפועל, אך האפליקציה לא תציע חלבי בזמן ההמתנה.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height:18),
              FilledButton(
                onPressed:(){
                  state.addFood(current,quantity,currentUnit);
                  Navigator.pop(context);
                },
                child:const Text('שמור ביומן'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';

class AddFoodToCatalogScreen extends StatefulWidget {
  const AddFoodToCatalogScreen({super.key, required this.state});
  final AppState state;

  @override
  State<AddFoodToCatalogScreen> createState()=>_AddFoodToCatalogScreenState();
}

class _AddFoodToCatalogScreenState extends State<AddFoodToCatalogScreen> {
  final name=TextEditingController();
  final category=TextEditingController(text:'אחר');
  final calories=TextEditingController();
  final protein=TextEditingController();
  final carbs=TextEditingController();
  final fat=TextEditingController();
  final unitName=TextEditingController(text:'מנה');
  final unitGrams=TextEditingController(text:'100');
  final labelText=TextEditingController();

  KosherStatus kosherStatus=KosherStatus.unknown;
  KosherFoodType kosherType=KosherFoodType.pareve;

  @override
  void dispose(){
    for(final c in [name,category,calories,protein,carbs,fat,unitName,unitGrams,labelText]){c.dispose();}
    super.dispose();
  }

  void _parseLabel(){
    final text=labelText.text;
    double? find(List<String> keys){
      for(final key in keys){
        final re=RegExp('$key[^0-9]{0,15}([0-9]+(?:[.,][0-9]+)?)',caseSensitive:false);
        final m=re.firstMatch(text);
        if(m!=null)return double.tryParse(m.group(1)!.replaceAll(',','.'));
      }
      return null;
    }
    final c=find(['קלוריות','אנרגיה']);
    final p=find(['חלבון']);
    final cb=find(['פחמימות']);
    final f=find(['שומן']);
    if(c!=null)calories.text=c.toStringAsFixed(c%1==0?0:1);
    if(p!=null)protein.text=p.toStringAsFixed(p%1==0?0:1);
    if(cb!=null)carbs.text=cb.toStringAsFixed(cb%1==0?0:1);
    if(f!=null)fat.text=f.toStringAsFixed(f%1==0?0:1);
    setState((){});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('פענוח Beta הושלם. יש לבדוק ולאשר את הנתונים לפני שמירה.')),
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('הוסף מזון למאגר')),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          Card(
            child:Padding(
              padding:const EdgeInsets.all(14),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  const Text('צילום תווית + AI',style:TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:6),
                  const Text(
                    'הממשק מוכן לחיבור מצלמה ו־AI. בגרסה הזו אפשר להדביק את הטקסט מהתווית '
                    'והמערכת תנסה לחלץ ערכים בסיסיים. חיבור צילום אמיתי יתווסף כשנחבר שירות AI.',
                  ),
                  const SizedBox(height:10),
                  TextField(
                    controller:labelText,
                    minLines:3,maxLines:6,
                    decoration:const InputDecoration(
                      labelText:'הדבק טקסט מתווית המזון',
                      border:OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height:8),
                  FilledButton.tonalIcon(
                    onPressed:_parseLabel,
                    icon:const Icon(Icons.document_scanner_outlined),
                    label:const Text('פענח תווית (Beta)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height:12),
          TextField(controller:name,decoration:const InputDecoration(labelText:'שם המזון',border:OutlineInputBorder())),
          const SizedBox(height:10),
          TextField(controller:category,decoration:const InputDecoration(labelText:'קטגוריה',border:OutlineInputBorder())),
          const SizedBox(height:10),
          DropdownButtonFormField<KosherStatus>(
            initialValue:kosherStatus,
            decoration:const InputDecoration(labelText:'מצב כשרות',border:OutlineInputBorder()),
            items:KosherStatus.values.map((v)=>DropdownMenuItem(value:v,child:Text(kosherStatusLabel(v)))).toList(),
            onChanged:(v)=>setState(()=>kosherStatus=v??KosherStatus.unknown),
          ),
          if(kosherStatus==KosherStatus.kosher)...[
            const SizedBox(height:10),
            DropdownButtonFormField<KosherFoodType>(
              initialValue:kosherType,
              decoration:const InputDecoration(labelText:'סיווג כשרותי',border:OutlineInputBorder()),
              items:KosherFoodType.values.map((v)=>DropdownMenuItem(value:v,child:Text(kosherLabel(v)))).toList(),
              onChanged:(v)=>setState(()=>kosherType=v??KosherFoodType.pareve),
            ),
          ],
          const SizedBox(height:14),
          const Text('ערכים ל־100 גרם',style:TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:_num(calories,'קלוריות')),
            const SizedBox(width:8),
            Expanded(child:_num(protein,'חלבון')),
          ]),
          Row(children:[
            Expanded(child:_num(carbs,'פחמימות')),
            const SizedBox(width:8),
            Expanded(child:_num(fat,'שומן')),
          ]),
          const SizedBox(height:8),
          const Text('מידה ביתית ראשונה',style:TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(controller:unitName,decoration:const InputDecoration(labelText:'שם המידה',border:OutlineInputBorder()))),
            const SizedBox(width:8),
            Expanded(child:_num(unitGrams,'גרם למידה')),
          ]),
          const SizedBox(height:16),
          FilledButton.icon(
            onPressed:_save,
            icon:const Icon(Icons.save_outlined),
            label:const Text('שמור במאגר'),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c,String label)=>Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:TextField(
      controller:c,
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
    ),
  );

  void _save(){
    final n=name.text.trim();
    if(n.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('יש להזין שם מזון.')));
      return;
    }
    final grams=double.tryParse(unitGrams.text.replaceAll(',','.'))??100;
    final id='custom_${DateTime.now().microsecondsSinceEpoch}';
    final food=FoodItem(
      id:id,
      name:n,
      category:category.text.trim().isEmpty?'אחר':category.text.trim(),
      type:kosherType,
      kosherStatus:kosherStatus,
      caloriesPer100g:double.tryParse(calories.text.replaceAll(',','.'))??0,
      proteinPer100g:double.tryParse(protein.text.replaceAll(',','.'))??0,
      carbsPer100g:double.tryParse(carbs.text.replaceAll(',','.'))??0,
      fatPer100g:double.tryParse(fat.text.replaceAll(',','.'))??0,
      units:{
        unitName.text.trim().isEmpty?'מנה':unitName.text.trim():grams,
        'גרם':1,
      },
      userCreated:true,
    );
    widget.state.addCustomFood(food);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$n נוסף למאגר')));
    Navigator.pop(context);
  }
}

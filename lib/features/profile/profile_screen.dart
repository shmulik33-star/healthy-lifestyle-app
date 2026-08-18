import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState()=>_ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TextEditingController? name,weight,target,calories,protein,customWait;
  String? goal,activity,style;
  int? workoutDays;
  bool keepKosher=true;
  bool separateMeatDairy=true;
  int waitMinutes=360;
  bool initialized=false;

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    if(initialized)return;
    initialized=true;
    final s=AppStateScope.of(context);
    name=TextEditingController(text:s.firstName);
    weight=TextEditingController(text:s.currentWeight.toStringAsFixed(1));
    target=TextEditingController(text:s.targetWeight.toStringAsFixed(1));
    calories=TextEditingController(text:'${s.calorieTarget}');
    protein=TextEditingController(text:'${s.proteinTarget}');
    customWait=TextEditingController(text:'${s.meatWaitMinutes}');
    goal=s.primaryGoal; activity=s.activityLevel; style=s.eatingStyle;
    workoutDays=s.workoutDaysPerWeek;
    keepKosher=s.kosherEnabled;
    separateMeatDairy=s.meatDairySeparationEnabled;
    waitMinutes=s.meatWaitMinutes;
  }

  @override
  void dispose(){
    for(final c in [name,weight,target,calories,protein,customWait]){c?.dispose();}
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    final s=AppStateScope.of(context);
    const waits=<int,String>{
      0:'ללא טיימר המתנה',
      60:'שעה',
      180:'3 שעות',
      300:'5 שעות',
      360:'6 שעות',
      -1:'זמן מותאם אישית',
    };
    final selectedWait=waits.containsKey(waitMinutes)?waitMinutes:-1;

    return Scaffold(
      appBar:AppBar(title:const Text('הפרופיל והיעדים שלי')),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          _f(name!,'שם פרטי'),
          Row(children:[
            Expanded(child:_f(weight!,'משקל נוכחי (ק״ג)',number:true)),
            const SizedBox(width:10),
            Expanded(child:_f(target!,'יעד משקל (ק״ג)',number:true)),
          ]),
          DropdownButtonFormField<String>(
            initialValue:goal,
            decoration:const InputDecoration(labelText:'המטרה העיקרית',border:OutlineInputBorder()),
            items:['ירידה במשקל','שמירה על המשקל','עלייה במסת שריר','שיפור הכושר']
                .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:(v)=>setState(()=>goal=v),
          ),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            initialValue:activity,
            decoration:const InputDecoration(labelText:'רמת פעילות גופנית',border:OutlineInputBorder()),
            items:['נמוכה','בינונית','גבוהה']
                .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:(v)=>setState(()=>activity=v),
          ),
          const SizedBox(height:12),
          DropdownButtonFormField<int>(
            initialValue:workoutDays,
            decoration:const InputDecoration(labelText:'מספר אימונים בשבוע',border:OutlineInputBorder()),
            items:List.generate(7,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v'))).toList(),
            onChanged:(v)=>setState(()=>workoutDays=v),
          ),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            initialValue:style,
            decoration:const InputDecoration(labelText:'סגנון אכילה',border:OutlineInputBorder()),
            items:['רגיל','ים תיכוני','דל פחמימות']
                .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:(v)=>setState(()=>style=v),
          ),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:_f(calories!,'יעד קלוריות יומי',number:true)),
            const SizedBox(width:10),
            Expanded(child:_f(protein!,'יעד חלבון (גרם)',number:true)),
          ]),
          OutlinedButton.icon(
            onPressed:(){
              s.primaryGoal=goal??s.primaryGoal;
              s.activityLevel=activity??s.activityLevel;
              calories!.text='${s.suggestedCalories()}';
              protein!.text='${s.suggestedProtein()}';
              setState((){});
            },
            icon:const Icon(Icons.auto_awesome),
            label:const Text('חשב לי הצעה לפי הפרופיל'),
          ),
          const SizedBox(height:18),
          Text('כשרות',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:6),
          SwitchListTile(
            value:keepKosher,
            title:const Text('אני רוצה שהאפליקציה תשמור עבורי על כשרות'),
            subtitle:const Text('מזון לא כשר או שכשרותו לא ידועה לא יוצע אוטומטית.'),
            onChanged:(v)=>setState(()=>keepKosher=v),
          ),
          if(keepKosher)...[
            SwitchListTile(
              value:separateMeatDairy,
              title:const Text('הפרדה בין בשר לחלב'),
              onChanged:(v)=>setState(()=>separateMeatDairy=v),
            ),
            if(separateMeatDairy)...[
              const SizedBox(height:6),
              DropdownButtonFormField<int>(
                initialValue:selectedWait,
                decoration:const InputDecoration(
                  labelText:'זמן המתנה מבשר לחלב',
                  border:OutlineInputBorder(),
                ),
                items:waits.entries
                    .map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
                onChanged:(v)=>setState((){
                  if(v==null)return;
                  if(v>=0)waitMinutes=v;
                  else waitMinutes=-1;
                }),
              ),
              if(waitMinutes==-1)...[
                const SizedBox(height:10),
                TextField(
                  controller:customWait,
                  keyboardType:TextInputType.number,
                  decoration:const InputDecoration(
                    labelText:'זמן מותאם בדקות (לדוגמה 360)',
                    border:OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height:16),
          FilledButton(
            onPressed:(){
              final finalWait=waitMinutes==-1
                  ? (int.tryParse(customWait!.text)??360)
                  : waitMinutes;
              s.updateProfile(
                name:name!.text.trim().isEmpty?s.firstName:name!.text.trim(),
                weight:double.tryParse(weight!.text.replaceAll(',','.'))??s.currentWeight,
                target:double.tryParse(target!.text.replaceAll(',','.'))??s.targetWeight,
                calories:int.tryParse(calories!.text)??s.calorieTarget,
                protein:int.tryParse(protein!.text)??s.proteinTarget,
                goal:goal,activity:activity,workoutDays:workoutDays,style:style,
                keepKosher:keepKosher,
                separateMeatDairy:keepKosher&&separateMeatDairy,
                waitMinutes:finalWait,
              );
              Navigator.pop(context);
            },
            child:const Text('שמור שינויים'),
          ),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c,String label,{bool number=false})=>
      Padding(
        padding:const EdgeInsets.only(bottom:12),
        child:TextField(
          controller:c,
          keyboardType:number
              ? const TextInputType.numberWithOptions(decimal:true)
              : TextInputType.text,
          decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
        ),
      );
}

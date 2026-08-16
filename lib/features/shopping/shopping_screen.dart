import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';
import 'pantry_screen.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});
  @override State<ShoppingScreen> createState()=>_ShoppingScreenState();
}
class _ShoppingScreenState extends State<ShoppingScreen> {
  bool initialized=false;
  @override void didChangeDependencies(){
    super.didChangeDependencies();
    if(!initialized){initialized=true; Future.microtask(()=>AppStateScope.of(context).buildSmartShoppingList());}
  }
  @override Widget build(BuildContext context){
    final state=AppStateScope.of(context);
    return Scaffold(
      appBar:AppBar(title:const Text('רשימת קניות חכמה'),actions:[
        IconButton(tooltip:'המזווה שלי',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AppStateScope(state:state,child:const PantryScreen()))),icon:const Icon(Icons.inventory_2_outlined)),
        IconButton(tooltip:'חשב מחדש לפי הצריכה והתפריט',onPressed:()=>state.buildSmartShoppingList(force:true),icon:const Icon(Icons.auto_awesome)),
        IconButton(tooltip:'הוסף פריט',onPressed:()=>_edit(context,state),icon:const Icon(Icons.add)),
      ]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>_edit(context,state),icon:const Icon(Icons.add),label:const Text('הוסף פריט')),
      body:AnimatedBuilder(animation:state,builder:(context,_){
        final items=[...state.shoppingItems]..sort((a,b){final c=a.category.compareTo(b.category);return c!=0?c:a.name.compareTo(b.name);});
        final categories=<String,List<ShoppingItem>>{};
        for(final item in items){(categories[item.category]??=[]).add(item);}
        return ListView(padding:const EdgeInsets.fromLTRB(16,16,16,90),children:[
          const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('הרשימה משלבת את התפריט לשבוע הבא עם הצריכה בפועל ב־7 הימים האחרונים. אפשר לערוך, למחוק, להוסיף ידנית ולציין כמה כבר יש בבית.'))),
          const SizedBox(height:8),
          if(items.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('הרשימה ריקה. לחץ “הוסף פריט” או על כפתור ✨ כדי לחשב המלצה.'))),
          for(final entry in categories.entries)...[
            Padding(padding:const EdgeInsets.only(top:12,bottom:4),child:Text(entry.key,style:Theme.of(context).textTheme.titleMedium)),
            ...entry.value.map((item)=>Card(child:Column(children:[
              CheckboxListTile(
                value:item.checked,
                onChanged:(v)=>state.toggleSmartShopping(item,v??false),
                title:Text(item.name,style:TextStyle(decoration:item.checked?TextDecoration.lineThrough:null)),
                subtitle:Text('${_fmt(item.quantity)} ${item.unit}${item.haveAtHome>0?' · בבית: ${_fmt(item.haveAtHome)}':''}'),
                secondary:PopupMenuButton<String>(
                  onSelected:(v){if(v=='edit')_edit(context,state,item:item);if(v=='delete')state.deleteShoppingItem(item);if(v=='why')_why(context,item);},
                  itemBuilder:(_)=>const [
                    PopupMenuItem(value:'edit',child:Text('ערוך / מלאי בבית')),
                    PopupMenuItem(value:'why',child:Text('למה הכמות הזאת?')),
                    PopupMenuItem(value:'delete',child:Text('מחק')),
                  ],
                ),
              ),
              if(item.source=='חכם' && item.reason.isNotEmpty)
                Align(alignment:AlignmentDirectional.centerStart,child:TextButton.icon(onPressed:()=>_why(context,item),icon:const Icon(Icons.info_outline,size:18),label:const Text('למה הכמות הזאת?'))),
            ]))),
          ],
          const SizedBox(height:12),
          const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('נשנושי הצלה שכדאי להחזיק בבית: ביצים, טונה, ירקות חתוכים, שקדים במנות מדודות, טחינה ופרי.'))),
        ]);
      }),
    );
  }

  Future<void> _why(BuildContext context,ShoppingItem item)=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(item.name),content:Text(item.reason.isEmpty?'פריט זה נוסף ידנית.':item.reason),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('סגור'))]));

  Future<void> _edit(BuildContext context,AppState state,{ShoppingItem? item}) async {
    final name=TextEditingController(text:item?.name??'');
    final qty=TextEditingController(text:item==null?'1':_fmt(item.quantity));
    final home=TextEditingController(text:item==null?'0':_fmt(item.haveAtHome));
    final unit=TextEditingController(text:item?.unit??'יחידות');
    var category=item?.category??'אחר';
    final categories=['ירקות ופירות','בשר ועוף','דגים','מוצרי חלב','ביצים','מזווה','קפואים','נשנושים','אחר'];
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(item==null?'הוסף פריט':'עריכת פריט'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'שם המוצר')),
        TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'כמות לקנייה')),
        TextField(controller:unit,decoration:const InputDecoration(labelText:'יחידה (יחידות / ק״ג / חבילות...)')),
        TextField(controller:home,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'כמה יש בבית')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:category,isExpanded:true,decoration:const InputDecoration(labelText:'קטגוריה'),items:categories.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setLocal(()=>category=v??category)),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('ביטול')),
        FilledButton(onPressed:(){
          final n=name.text.trim(); if(n.isEmpty)return;
          final q=double.tryParse(qty.text.replaceAll(',','.'))??1;
          final h=double.tryParse(home.text.replaceAll(',','.'))??0;
          if(item==null){state.addShoppingItem(n,q,unit.text.trim().isEmpty?'יחידות':unit.text.trim(),category);}
          else{state.updateShoppingItem(item,name:n,quantity:q,unit:unit.text.trim(),category:category,haveAtHome:h);}
          Navigator.pop(ctx);
        },child:const Text('שמור')),
      ],
    )));
    name.dispose();qty.dispose();home.dispose();unit.dispose();
  }
  static String _fmt(double v)=>v==v.roundToDouble()?v.toInt().toString():v.toStringAsFixed(1);
}

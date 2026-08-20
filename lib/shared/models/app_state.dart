import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/food_catalog.dart';
import 'food.dart';

part 'app_state_fitness.dart';
part 'app_state_kosher.dart';
part 'app_state_shopping.dart';

class MealEntry {
  MealEntry({required this.foodId, required this.name, required this.quantity, required this.unit, required this.grams, required this.calories, required this.protein, required this.carbs, required this.fat, required this.type, required this.time});
  final String foodId;
  final String name;
  final double quantity;
  final String unit;
  final double grams;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final KosherFoodType type;
  final DateTime time;

  Map<String,dynamic> toJson() => {'foodId':foodId,'name':name,'quantity':quantity,'unit':unit,'grams':grams,'calories':calories,'protein':protein,'carbs':carbs,'fat':fat,'type':type.name,'time':time.toIso8601String()};
  factory MealEntry.fromJson(Map<String,dynamic> j) => MealEntry(foodId:j['foodId']??'', name:j['name']??'', quantity:(j['quantity']??1).toDouble(), unit:j['unit']??'יחידה', grams:(j['grams']??0).toDouble(), calories:j['calories']??0, protein:(j['protein']??0).toDouble(), carbs:(j['carbs']??0).toDouble(), fat:(j['fat']??0).toDouble(), type:KosherFoodType.values.firstWhere((e)=>e.name==j['type'],orElse:()=>KosherFoodType.pareve), time:DateTime.tryParse(j['time']??'')??DateTime.now());
}

class WeightEntry {
  WeightEntry(this.date,this.weight);
  final DateTime date;
  final double weight;
  Map<String,dynamic> toJson()=>{'date':date.toIso8601String(),'weight':weight};
  factory WeightEntry.fromJson(Map<String,dynamic> j)=>WeightEntry(DateTime.tryParse(j['date']??'')??DateTime.now(),(j['weight']??0).toDouble());
}

class PlannedMeal {
  PlannedMeal({required this.title, required this.description, required this.type, required this.calories, required this.shopping});
  final String title;
  final String description;
  final KosherFoodType type;
  final int calories;
  final Map<String,int> shopping;

  Map<String,dynamic> toJson()=>{'title':title,'description':description,'type':type.name,'calories':calories,'shopping':shopping};
  factory PlannedMeal.fromJson(Map<String,dynamic> j)=>PlannedMeal(
    title:j['title']??'',
    description:j['description']??'',
    type:KosherFoodType.values.firstWhere((e)=>e.name==j['type'],orElse:()=>KosherFoodType.pareve),
    calories:j['calories']??0,
    shopping:Map<String,int>.from((j['shopping'] as Map?)??{}),
  );
}

class PlannedDay {
  PlannedDay({required this.day, required this.meals});
  final String day;
  final List<PlannedMeal> meals;
  Map<String,dynamic> toJson()=>{'day':day,'meals':meals.map((e)=>e.toJson()).toList()};
  factory PlannedDay.fromJson(Map<String,dynamic> j)=>PlannedDay(day:j['day']??'',meals:((j['meals'] as List?)??[]).map((e)=>PlannedMeal.fromJson(Map<String,dynamic>.from(e))).toList());
}

class PantryItem {
  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.foodId = '',
    this.lowStockThreshold = 1,
  });

  final String id;
  String foodId;
  String name;
  double quantity;
  String unit;
  String category;
  double lowStockThreshold;

  bool get isLow => quantity <= lowStockThreshold;

  Map<String, dynamic> toJson() => {
        'id': id,
        'foodId': foodId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        'lowStockThreshold': lowStockThreshold,
      };

  factory PantryItem.fromJson(Map<String, dynamic> j) => PantryItem(
        id: j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        foodId: j['foodId'] ?? '',
        name: j['name'] ?? '',
        quantity: (j['quantity'] ?? 0).toDouble(),
        unit: j['unit'] ?? 'יחידות',
        category: j['category'] ?? 'אחר',
        lowStockThreshold: (j['lowStockThreshold'] ?? 1).toDouble(),
      );
}

class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.source = 'ידני',
    this.reason = '',
    this.checked = false,
    this.haveAtHome = 0,
  });
  final String id;
  String name;
  double quantity;
  String unit;
  String category;
  String source;
  String reason;
  bool checked;
  double haveAtHome;

  Map<String,dynamic> toJson()=>{
    'id':id,'name':name,'quantity':quantity,'unit':unit,'category':category,
    'source':source,'reason':reason,'checked':checked,'haveAtHome':haveAtHome,
  };
  factory ShoppingItem.fromJson(Map<String,dynamic> j)=>ShoppingItem(
    id:j['id']??DateTime.now().microsecondsSinceEpoch.toString(),
    name:j['name']??'', quantity:(j['quantity']??1).toDouble(),
    unit:j['unit']??'יחידה', category:j['category']??'אחר',
    source:j['source']??'ידני', reason:j['reason']??'',
    checked:j['checked']==true, haveAtHome:(j['haveAtHome']??0).toDouble(),
  );
}

class WorkoutExercise {
  const WorkoutExercise(this.name,this.sets,this.reps,this.equipment,this.muscleGroup);
  final String name;
  final int sets;
  final int reps;
  final String equipment;
  final String muscleGroup;
}

class DailySnapshot {
  const DailySnapshot({
    required this.dayKey,
    required this.waterCups,
    required this.steps,
    required this.workoutCompleted,
  });

  final String dayKey;
  final int waterCups;
  final int steps;
  final bool workoutCompleted;

  Map<String,dynamic> toJson()=>{
    'dayKey':dayKey,
    'waterCups':waterCups,
    'steps':steps,
    'workoutCompleted':workoutCompleted,
  };

  factory DailySnapshot.fromJson(Map<String,dynamic> j)=>DailySnapshot(
    dayKey:j['dayKey']??'',
    waterCups:j['waterCups']??0,
    steps:j['steps']??0,
    workoutCompleted:j['workoutCompleted']==true,
  );
}

class AppState extends ChangeNotifier {
  AppState(){ if (weeklyPlan.isEmpty) generateWeeklyPlan(save:false); }
  String firstName = 'שמוליק';
  int age = 50;
  double heightCm = 175;
  double currentWeight = 105;
  double targetWeight = 90;
  int calorieTarget = 1900;
  int proteinTarget = 120;
  int carbTarget = 150;
  int fatTarget = 70;
  int waterCups = 0;
  int waterTarget = 9;
  int steps = 0;
  int stepsTarget = 7000;
  bool workoutCompleted = false;
  int dayStartMinutes = 300;
  String dailyStateKey = '';
  final List<DailySnapshot> dailyHistory = [];
  bool kosherEnabled = true;
  bool meatDairySeparationEnabled = true;
  int meatWaitMinutes = 360;
  final List<FoodItem> customFoods = [];
  String primaryGoal = 'ירידה במשקל';
  String activityLevel = 'בינונית';
  int workoutDaysPerWeek = 3;
  String eatingStyle = 'רגיל';

  final List<MealEntry> meals = [];
  final List<WeightEntry> weights = [];
  final Map<String,bool> equipment = {
    'משקולות יד':true,'ספסל':true,'Lat Pulldown':true,'Seated Row':true,'Cable Machine':true,'Leg Press':true,'הליכון':true,'TRX':false,'Smith Machine':false,'גומיות התנגדות':false,'מזרן':true
  };
  final List<PlannedDay> weeklyPlan = [];
  final Map<String,bool> shoppingChecked = {};
  final List<ShoppingItem> shoppingItems = [];
  bool shoppingInitialized = false;
  final List<PantryItem> pantryItems = [];

  static const _storageKey = 'stage10_state_v1';
  static const _oldStorageKey = 'stage9_state_v1';

  static Future<AppState> load() async {
    final state = AppState();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? prefs.getString(_oldStorageKey);
    if (raw == null) {
      state.weights.add(WeightEntry(DateTime.now(), state.currentWeight));
      state.dailyStateKey=state.dayKeyAt(DateTime.now());
      state.generateWeeklyPlan(save:false);
      await state._save();
      return state;
    }
    try { state._readJson(jsonDecode(raw) as Map<String,dynamic>); } catch (_) {}
    if (state.dailyStateKey.isEmpty) {
      state.dailyStateKey=state.dayKeyAt(DateTime.now());
    } else {
      state.ensureCurrentDay(now:DateTime.now(),notify:false,save:false);
    }
    if (state.weeklyPlan.isEmpty) state.generateWeeklyPlan(save:false);
    await state._save();
    return state;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  Map<String,dynamic> _toJson()=>{
    'firstName':firstName,'age':age,'heightCm':heightCm,'currentWeight':currentWeight,'targetWeight':targetWeight,
    'calorieTarget':calorieTarget,'proteinTarget':proteinTarget,'carbTarget':carbTarget,'fatTarget':fatTarget,
    'waterCups':waterCups,'waterTarget':waterTarget,'steps':steps,'stepsTarget':stepsTarget,'workoutCompleted':workoutCompleted,
    'dayStartMinutes':dayStartMinutes,'dailyStateKey':dailyStateKey,'dailyHistory':dailyHistory.map((e)=>e.toJson()).toList(),
    'kosherEnabled':kosherEnabled,'meatDairySeparationEnabled':meatDairySeparationEnabled,'meatWaitMinutes':meatWaitMinutes,
    'customFoods':customFoods.map((e)=>e.toJson()).toList(),
    'primaryGoal':primaryGoal,'activityLevel':activityLevel,'workoutDaysPerWeek':workoutDaysPerWeek,'eatingStyle':eatingStyle,
    'meals':meals.map((e)=>e.toJson()).toList(),'weights':weights.map((e)=>e.toJson()).toList(),'equipment':equipment,
    'weeklyPlan':weeklyPlan.map((e)=>e.toJson()).toList(),'shoppingChecked':shoppingChecked,
    'shoppingItems':shoppingItems.map((e)=>e.toJson()).toList(),'shoppingInitialized':shoppingInitialized,
    'pantryItems':pantryItems.map((e)=>e.toJson()).toList(),
  };

  void _readJson(Map<String,dynamic> j) {
    firstName=j['firstName']??firstName; age=j['age']??age; heightCm=(j['heightCm']??heightCm).toDouble(); currentWeight=(j['currentWeight']??currentWeight).toDouble(); targetWeight=(j['targetWeight']??targetWeight).toDouble();
    calorieTarget=j['calorieTarget']??calorieTarget; proteinTarget=j['proteinTarget']??proteinTarget; carbTarget=j['carbTarget']??carbTarget; fatTarget=j['fatTarget']??fatTarget;
    waterCups=j['waterCups']??waterCups; waterTarget=j['waterTarget']??waterTarget; steps=j['steps']??steps; stepsTarget=j['stepsTarget']??stepsTarget; workoutCompleted=j['workoutCompleted']??workoutCompleted;
    dayStartMinutes=((j['dayStartMinutes']??dayStartMinutes) as num).toInt().clamp(0,1439);
    dailyStateKey=j['dailyStateKey']??dailyStateKey;
    dailyHistory..clear()..addAll(((j['dailyHistory'] as List?)??[]).map((e)=>DailySnapshot.fromJson(Map<String,dynamic>.from(e))));
    kosherEnabled=j['kosherEnabled']??kosherEnabled;
    meatDairySeparationEnabled=j['meatDairySeparationEnabled']??meatDairySeparationEnabled;
    meatWaitMinutes=j['meatWaitMinutes']??meatWaitMinutes;
    customFoods..clear()..addAll(((j['customFoods'] as List?)??[]).map((e)=>FoodItem.fromJson(Map<String,dynamic>.from(e))));
    primaryGoal=j['primaryGoal']??primaryGoal; activityLevel=j['activityLevel']??activityLevel; workoutDaysPerWeek=j['workoutDaysPerWeek']??workoutDaysPerWeek; eatingStyle=j['eatingStyle']??eatingStyle;
    meals..clear()..addAll(((j['meals'] as List?)??[]).map((e)=>MealEntry.fromJson(Map<String,dynamic>.from(e))));
    weights..clear()..addAll(((j['weights'] as List?)??[]).map((e)=>WeightEntry.fromJson(Map<String,dynamic>.from(e))));
    if (j['equipment'] is Map) { for (final e in Map<String,dynamic>.from(j['equipment']).entries) { equipment[e.key]=e.value==true; } }
    weeklyPlan..clear()..addAll(((j['weeklyPlan'] as List?)??[]).map((e)=>PlannedDay.fromJson(Map<String,dynamic>.from(e))));
    shoppingChecked..clear();
    if (j['shoppingChecked'] is Map) { for (final e in Map<String,dynamic>.from(j['shoppingChecked']).entries) { shoppingChecked[e.key]=e.value==true; } }
    shoppingItems..clear()..addAll(((j['shoppingItems'] as List?)??[]).map((e)=>ShoppingItem.fromJson(Map<String,dynamic>.from(e))));
    shoppingInitialized=j['shoppingInitialized']==true;
    pantryItems..clear()..addAll(((j['pantryItems'] as List?)??[]).map((e)=>PantryItem.fromJson(Map<String,dynamic>.from(e))));
  }

  DateTime logicalDayDateAt(DateTime time) {
    final shifted=time.subtract(Duration(minutes:dayStartMinutes));
    return DateTime(shifted.year,shifted.month,shifted.day);
  }

  String dayKeyAt(DateTime time) {
    final d=logicalDayDateAt(time);
    String two(int v)=>v.toString().padLeft(2,'0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  DateTime dayStartAt(DateTime time) {
    final d=logicalDayDateAt(time);
    final hour=dayStartMinutes~/60;
    final minute=dayStartMinutes.remainder(60);
    return DateTime(d.year,d.month,d.day,hour,minute);
  }

  DateTime dayEndAt(DateTime time) {
    final d=logicalDayDateAt(time);
    final next=DateTime(d.year,d.month,d.day+1);
    final hour=dayStartMinutes~/60;
    final minute=dayStartMinutes.remainder(60);
    return DateTime(next.year,next.month,next.day,hour,minute);
  }

  String get dayStartTimeLabel {
    final h=(dayStartMinutes~/60).toString().padLeft(2,'0');
    final m=dayStartMinutes.remainder(60).toString().padLeft(2,'0');
    return '$h:$m';
  }

  bool ensureCurrentDay({DateTime? now,bool notify=true,bool save=true}) {
    final current=now??DateTime.now();
    final key=dayKeyAt(current);
    if(dailyStateKey.isEmpty){
      dailyStateKey=key;
      if(save)_save();
      return false;
    }
    if(dailyStateKey==key)return false;

    dailyHistory.removeWhere((e)=>e.dayKey==dailyStateKey);
    dailyHistory.add(DailySnapshot(
      dayKey:dailyStateKey,
      waterCups:waterCups,
      steps:steps,
      workoutCompleted:workoutCompleted,
    ));
    if(dailyHistory.length>120){
      dailyHistory.removeRange(0,dailyHistory.length-120);
    }
    waterCups=0;
    steps=0;
    workoutCompleted=false;
    dailyStateKey=key;
    if(notify)notifyListeners();
    if(save)_save();
    return true;
  }

  void setDayStartMinutes(int minutes){
    dayStartMinutes=minutes.clamp(0,1439);
    dailyStateKey=dayKeyAt(DateTime.now());
    notifyListeners();
    _save();
  }

  List<MealEntry> mealsForDayAt(DateTime now) {
    final start=dayStartAt(now);
    final end=dayEndAt(now);
    return meals.where((m)=>!m.time.isBefore(start)&&m.time.isBefore(end)).toList()
      ..sort((a,b)=>a.time.compareTo(b.time));
  }

  int get caloriesEaten => todayMeals.fold(0,(s,m)=>s+m.calories);
  double get proteinEaten => todayMeals.fold(0,(s,m)=>s+m.protein);
  double get carbsEaten => todayMeals.fold(0,(s,m)=>s+m.carbs);
  double get fatEaten => todayMeals.fold(0,(s,m)=>s+m.fat);
  int get remainingCalories => (calorieTarget-caloriesEaten).clamp(0, calorieTarget);
  double get remainingProtein => (proteinTarget-proteinEaten).clamp(0, proteinTarget.toDouble());
  List<MealEntry> get todayMeals => mealsForDayAt(DateTime.now());

  List<FoodItem> get allFoods => [...foodCatalog, ...customFoods];

  DateTime? get lastMeatTime => _kosherLastMeatTime(this);
  DateTime? get dairyAllowedAt => _kosherDairyAllowedAt(this);
  bool get dairyAllowed => _kosherDairyAllowed(this);
  Duration get dairyRemaining => _kosherDairyRemaining(this);

  bool foodAllowedForRecommendations(FoodItem food) =>
      _kosherFoodAllowedForRecommendations(this, food);

  FoodItem foodById(String id)=>allFoods.firstWhere((f)=>f.id==id);

  void addFood(FoodItem food,double quantity,String unit) {
    ensureCurrentDay();
    final g=food.gramsFor(unit,quantity);
    final entry=MealEntry(
      foodId:food.id,name:food.name,quantity:quantity,unit:unit,grams:g,
      calories:food.caloriesFor(unit,quantity),
      protein:food.proteinFor(unit,quantity),
      carbs:food.carbsFor(unit,quantity),
      fat:food.fatFor(unit,quantity),
      type:food.type,time:DateTime.now(),
    );
    meals.add(entry);
    consumeFromPantryByMeal(entry);
    notifyListeners();
    _save();
  }

  void addCustomFood(FoodItem food){
    customFoods.removeWhere((f)=>f.id==food.id || f.name.trim().toLowerCase()==food.name.trim().toLowerCase());
    customFoods.add(food);

    for(final p in pantryItems){
      if(_sameFoodName(p.name,food.name)) p.foodId=food.id;
    }
    notifyListeners();
    _save();
  }

  void deleteCustomFood(FoodItem food){
    customFoods.removeWhere((f)=>f.id==food.id);
    notifyListeners();
    _save();
  }

  static bool _sameFoodName(String a,String b){
    final rawA=a.trim().toLowerCase();
    final rawB=b.trim().toLowerCase();
    if(rawA.contains('ביצ') && rawB.contains('ביצ')) return true;
    if(rawA.contains('טונה') && rawB.contains('טונה')) return true;
    String n(String x)=>x
      .replaceAll('׳','').replaceAll("'",'')
      .replaceAll('ים','').replaceAll('ות','')
      .trim().toLowerCase();
    final na=n(rawA), nb=n(rawB);
    return na==nb || na.contains(nb) || nb.contains(na);
  }
  void removeMeal(MealEntry meal){meals.remove(meal);notifyListeners();_save();}
  void addWater(){ensureCurrentDay();if(waterCups<20)waterCups++;notifyListeners();_save();}
  void completeWorkout(){ensureCurrentDay();workoutCompleted=true;notifyListeners();_save();}
  void toggleEquipment(String name,bool value){equipment[name]=value;notifyListeners();_save();}
  void updateProfile({
    required String name,required double weight,required double target,
    required int calories,required int protein,String? goal,String? activity,
    int? workoutDays,String? style,bool? keepKosher,bool? separateMeatDairy,
    int? waitMinutes,int? dailyStartMinutes,
  }){
    firstName=name; currentWeight=weight; targetWeight=target;
    calorieTarget=calories; proteinTarget=protein;
    if(goal!=null) primaryGoal=goal;
    if(activity!=null) activityLevel=activity;
    if(workoutDays!=null) workoutDaysPerWeek=workoutDays;
    if(style!=null) eatingStyle=style;
    if(keepKosher!=null) kosherEnabled=keepKosher;
    if(separateMeatDairy!=null) meatDairySeparationEnabled=separateMeatDairy;
    if(waitMinutes!=null) meatWaitMinutes=waitMinutes;
    if(dailyStartMinutes!=null){
      dayStartMinutes=dailyStartMinutes.clamp(0,1439);
      dailyStateKey=dayKeyAt(DateTime.now());
    }
    notifyListeners(); generateWeeklyPlan();
  }

  int suggestedCalories() {
    final base = (currentWeight * 22).round();
    final factor = switch(activityLevel){'נמוכה'=>1.15,'גבוהה'=>1.45,_=>1.30};
    var estimate = (base * factor).round();
    if(primaryGoal=='ירידה במשקל') estimate -= 350;
    if(primaryGoal=='עלייה במסת שריר') estimate += 200;
    return estimate.clamp(1200, 4000);
  }

  int suggestedProtein() {
    final factor = primaryGoal=='עלייה במסת שריר' ? 1.8 : 1.5;
    return (currentWeight * factor).round().clamp(60, 250);
  }

  String get dailyInsight {
    if(caloriesEaten==0) return 'עוד לא תיעדת ארוחה היום. התחלה פשוטה היא לתעד את הארוחה הבאה בלי לחפש דיוק מושלם.';
    if(proteinEaten < proteinTarget * .55 && caloriesEaten > calorieTarget * .55) return 'יותר ממחצית הקלוריות כבר נוצלו, אבל החלבון עדיין נמוך יחסית. בארוחה הבאה כדאי לתת עדיפות למקור חלבון.';
    if(waterCups < waterTarget * .5) return 'המים מעט מאחור היום. אפשר להוסיף כוס עכשיו ולהמשיך בהדרגה.';
    if(!dairyAllowed) return 'מצב הכשרות כרגע בשרי. ההמלצות מסוננות לפי זמן ההמתנה שהגדרת בפרופיל.';
    return 'היום מתקדם בצורה מאוזנת. נשארו $remainingCalories קלוריות וכ-${remainingProtein.toStringAsFixed(0)} גרם חלבון ליעד.';
  }

  String get weightTrend {
    if(weights.length < 2) return 'נדרשות לפחות שתי שקילות כדי לזהות מגמה.';
    final sorted=[...weights]..sort((a,b)=>a.date.compareTo(b.date));
    final delta=sorted.last.weight-sorted.first.weight;
    if(delta.abs()<0.2) return 'המשקל יציב יחסית בתקופה המתועדת.';
    return delta<0 ? 'ירידה של ${delta.abs().toStringAsFixed(1)} ק״ג בתקופה המתועדת.' : 'עלייה של ${delta.toStringAsFixed(1)} ק״ג בתקופה המתועדת.';
  }
  void addWeight(double value){currentWeight=value;weights.add(WeightEntry(DateTime.now(),value));notifyListeners();_save();}

  void generateWeeklyPlan({bool save=true}) {
    final days=['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת'];
    final breakfasts=[
      PlannedMeal(title:'בוקר',description:'2 ביצים, סלט וטחינה',type:KosherFoodType.pareve,calories:360,shopping:{'ביצים':2,'ירקות לסלט':2,'טחינה':1}),
      PlannedMeal(title:'בוקר',description:'יוגורט עשיר בחלבון ושקדים',type:KosherFoodType.dairy,calories:300,shopping:{'יוגורט עשיר בחלבון':1,'שקדים':1}),
      PlannedMeal(title:'בוקר',description:'קוטג׳, ירקות ופרוסת לחם מלא',type:KosherFoodType.dairy,calories:340,shopping:{'קוטג׳ 5%':1,'ירקות לסלט':2,'לחם מלא':2}),
    ];
    final lunches=[
      PlannedMeal(title:'צהריים',description:'חזה עוף, סלט גדול וכף טחינה',type:KosherFoodType.meat,calories:550,shopping:{'חזה עוף':1,'ירקות לסלט':4,'טחינה':1}),
      PlannedMeal(title:'צהריים',description:'פרגית, ירקות וקינואה',type:KosherFoodType.meat,calories:620,shopping:{'פרגית':1,'ירקות לסלט':3,'קינואה':1}),
      PlannedMeal(title:'צהריים',description:'סלמון, ירקות ועדשים',type:KosherFoodType.pareve,calories:560,shopping:{'סלמון':1,'ירקות לסלט':3,'עדשים':1}),
    ];
    final dinnersPareve=[
      PlannedMeal(title:'ערב',description:'טונה, ביצה וסלט גדול',type:KosherFoodType.pareve,calories:410,shopping:{'טונה במים':1,'ביצים':1,'ירקות לסלט':3}),
      PlannedMeal(title:'ערב',description:'טופו מוקפץ עם ירקות',type:KosherFoodType.pareve,calories:420,shopping:{'טופו':1,'ירקות לסלט':3}),
      PlannedMeal(title:'ערב',description:'ביצים, אבוקדו וירקות',type:KosherFoodType.pareve,calories:430,shopping:{'ביצים':2,'אבוקדו':1,'ירקות לסלט':2}),
    ];
    final dinnersDairy=[
      PlannedMeal(title:'ערב',description:'קוטג׳, סלט ופרוסת לחם מלא',type:KosherFoodType.dairy,calories:390,shopping:{'קוטג׳ 5%':1,'ירקות לסלט':3,'לחם מלא':2}),
      PlannedMeal(title:'ערב',description:'יוגורט עשיר בחלבון, פרי ושקדים',type:KosherFoodType.dairy,calories:360,shopping:{'יוגורט עשיר בחלבון':1,'תפוח':1,'שקדים':1}),
    ];
    final snack=PlannedMeal(title:'נשנוש',description:'פרי + חופן קטן של שקדים',type:KosherFoodType.pareve,calories:180,shopping:{'פרי':1,'שקדים':1});
    weeklyPlan.clear();
    for(var i=0;i<days.length;i++){
      final breakfast=breakfasts[i%breakfasts.length];
      final lunch=lunches[i%lunches.length];
      final dinner=lunch.type==KosherFoodType.meat ? dinnersPareve[i%dinnersPareve.length] : dinnersDairy[i%dinnersDairy.length];
      weeklyPlan.add(PlannedDay(day:days[i],meals:[breakfast,lunch,dinner,snack]));
    }
    notifyListeners();
    if(save)_save();
  }

  Map<String,int> get shoppingTotals => _shoppingTotalsFor(this);

  void toggleShopping(String item,bool value){shoppingChecked[item]=value;notifyListeners();_save();}

  Map<String,double> get last7DayConsumption => _last7DayConsumptionFor(this);

  void buildSmartShoppingList({bool force=false}) {
    if(shoppingInitialized && !force) return;
    shoppingItems
      ..clear()
      ..addAll(_smartShoppingItemsFor(this));
    shoppingInitialized=true;
    notifyListeners();
    _save();
  }

  void addShoppingItem(String name,double quantity,String unit,String category){
    shoppingItems.add(ShoppingItem(
      id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,
      quantity:quantity,unit:unit,category:category,source:'ידני',
    ));
    shoppingInitialized=true; notifyListeners(); _save();
  }
  void updateShoppingItem(ShoppingItem item,{String? name,double? quantity,String? unit,String? category,double? haveAtHome}){
    if(name!=null)item.name=name;if(quantity!=null)item.quantity=quantity;if(unit!=null)item.unit=unit;
    if(category!=null)item.category=category;if(haveAtHome!=null)item.haveAtHome=haveAtHome;
    notifyListeners();_save();
  }
  void deleteShoppingItem(ShoppingItem item){shoppingItems.remove(item);notifyListeners();_save();}
  void toggleSmartShopping(ShoppingItem item,bool value){item.checked=value;notifyListeners();_save();}

  PantryItem? pantryByName(String name) => _pantryByExactName(this, name);

  void addPantryItem(
    String name,
    double quantity,
    String unit,
    String category, {
    double lowStockThreshold = 1,
    String foodId = '',
  }) {
    if(foodId.isEmpty){
      for(final f in allFoods){
        if(_sameFoodName(f.name,name)){ foodId=f.id; break; }
      }
    }
    PantryItem? existing;
    for(final p in pantryItems){
      if((foodId.isNotEmpty && p.foodId==foodId) || _sameFoodName(p.name,name)){
        existing=p; break;
      }
    }
    if (existing != null) {
      existing.quantity += quantity;
      if(foodId.isNotEmpty) existing.foodId=foodId;
      existing.unit = unit;
      existing.category = category;
      existing.lowStockThreshold = lowStockThreshold;
    } else {
      pantryItems.add(PantryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        foodId: foodId,
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        lowStockThreshold: lowStockThreshold,
      ));
    }
    notifyListeners();
    _save();
  }

  void updatePantryItem(
    PantryItem item, {
    String? name,
    double? quantity,
    String? unit,
    String? category,
    double? lowStockThreshold,
  }) {
    if (name != null) item.name = name;
    if (quantity != null) item.quantity = quantity;
    if (unit != null) item.unit = unit;
    if (category != null) item.category = category;
    if (lowStockThreshold != null) item.lowStockThreshold = lowStockThreshold;
    notifyListeners();
    _save();
  }

  void deletePantryItem(PantryItem item) {
    pantryItems.remove(item);
    notifyListeners();
    _save();
  }

  void addPurchasedShoppingToPantry() {
    final bought = shoppingItems.where((x) => x.checked).toList();
    for (final item in bought) {
      addPantryItem(item.name, item.quantity, item.unit, item.category);
    }
    shoppingItems.removeWhere((x) => x.checked);
    notifyListeners();
    _save();
  }

  void consumeFromPantryByMeal(MealEntry meal) {
    PantryItem? item;
    for(final p in pantryItems){
      if(meal.foodId.isNotEmpty && p.foodId==meal.foodId){ item=p; break; }
    }
    if(item==null){
      for(final p in pantryItems){
        if(_sameFoodName(p.name,meal.name)){ item=p; break; }
      }
    }
    if(item==null) return;

    double used=meal.quantity;
    if(meal.foodId=='egg' || meal.name.contains('ביצה')){
      used=meal.grams/50.0;
    }else if(item.unit.contains('גרם')){
      used=meal.grams;
    }else if(item.unit.contains('ק״ג') || item.unit.contains('קג')){
      used=meal.grams/1000.0;
    }
    item.quantity=(item.quantity-used).clamp(0,double.infinity).toDouble();
  }

  List<PantryItem> get lowStockPantry =>
      pantryItems.where((p) => p.isLow).toList();

  String get pantryInsight {
    if (pantryItems.isEmpty) {
      return 'המזווה עדיין ריק. אפשר להוסיף מוצרים ידנית או להעביר אליו פריטים שסומנו כנקנו.';
    }
    if (lowStockPantry.isNotEmpty) {
      return '${lowStockPantry.length} מוצרים עומדים להיגמר.';
    }
    return 'המלאי בבית נראה טוב כרגע.';
  }

  List<WorkoutExercise> get todayWorkout => _fitnessTodayWorkout(this);

  WorkoutExercise alternativeFor(WorkoutExercise current) =>
      _fitnessAlternativeFor(this, current);

  List<String> get smartFoodSuggestions {
    final allowed=allFoods.where(foodAllowedForRecommendations).toList()
      ..sort((a,b)=>b.proteinPer100g.compareTo(a.proteinPer100g));
    if(allowed.isEmpty) return ['לא מצאתי כרגע מזון מתאים לכל ההגדרות'];
    return allowed.take(3).map((f)=>f.name).toList();
  }

  String get kosherStateText => _kosherStateText(this);

  String coachResponse(String question){
    final q=question.trim();
    final kosher=kosherStateText;
    if(q.contains('יעד')||q.contains('מטרה')||q.contains('פרופיל')){
      return 'המטרה שהגדרת היא $primaryGoal, עם $workoutDaysPerWeek אימונים בשבוע ורמת פעילות $activityLevel. היעד היומי כרגע הוא $calorieTarget קלוריות ו-$proteinTarget גרם חלבון. אפשר לשנות אותם במסך הפרופיל.';
    }
    if(q.contains('התקדמות')||q.contains('משקל')){
      return '$weightTrend היום ציון הדרך החשוב יותר הוא עקביות: $dailyInsight';
    }
    if(q.contains('אימון')||q.contains('כושר')||q.contains('מכשיר')){
      final names=todayWorkout.map((e)=>e.name).join(', ');
      return '$kosher. לגבי הכושר: לפי הציוד שסימנת, האימון המתאים כרגע כולל $names. אם מכשיר תפוס, אוכל להציע חלופה מאותו סוג תנועה.';
    }
    if(q.contains('רעב')||q.contains('לאכול')||q.contains('נשנ')){
      return '$kosher. נשארו לך כ-$remainingCalories קלוריות וכ-${remainingProtein.toStringAsFixed(0)} גרם חלבון ליעד. הייתי בוחר אחת מהאפשרויות: ${smartFoodSuggestions.join(' / ')}.';
    }
    if(q.contains('שבוע')||q.contains('תפריט')||q.contains('קניות')){
      return 'יש לך תפריט שבועי דינמי ורשימת קניות שנגזרת ממנו. כרגע הרשימה כוללת ${shoppingTotals.length} סוגי מוצרים. אפשר לרענן את התפריט והקניות יחד.';
    }
    return 'היום אכלת $caloriesEaten מתוך $calorieTarget קלוריות ו-${proteinEaten.toStringAsFixed(0)} מתוך $proteinTarget גרם חלבון. $kosher. הצעד הבא שאני מציע: ${smartFoodSuggestions.first}.';
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key,required AppState state,required super.child}):super(notifier:state);
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    final value = scope?.notifier;
    if (value == null) {
      throw FlutterError('AppStateScope לא נמצא או שאין בו AppState פעיל');
    }
    return value;
  }
}

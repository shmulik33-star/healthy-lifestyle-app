import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/shared/data/food_catalog.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main(){test('adding meat creates six-hour dairy wait',(){final s=AppState();final chicken=foodCatalog.firstWhere((f)=>f.id=='chicken');s.addFood(chicken,1,'חתיכה בינונית');expect(s.lastMeatTime,isNotNull);expect(s.dairyAllowedAt!.difference(s.lastMeatTime!).inMinutes,360);});}

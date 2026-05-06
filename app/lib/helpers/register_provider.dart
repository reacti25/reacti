import 'package:achiar_expert_app/provider/auth_provider.dart';
import 'package:provider/provider.dart';

var providers = [
  ChangeNotifierProvider<AuthProvider>(create: (context) => AuthProvider()),
];

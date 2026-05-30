import 'package:linkup/services/linkup_backend.dart';

class LinkUpRepository extends LinkUpBackend {
  LinkUpRepository({super.client});
}

class FakeRepository extends LinkUpRepository {
  FakeRepository({super.client});
}

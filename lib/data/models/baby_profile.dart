/// 아기 프로필. 첫 실행 온보딩에서 입력하고 설정에서 수정할 수 있다.
class BabyProfile {
  final String? name;
  final DateTime? birthDate;
  final String? photoPath;

  const BabyProfile({this.name, this.birthDate, this.photoPath});

  /// 온보딩을 마쳤는지(이름·생년월일은 필수, 사진은 선택).
  bool get isComplete =>
      name != null && name!.trim().isNotEmpty && birthDate != null;

  BabyProfile copyWith({
    String? name,
    DateTime? birthDate,
    String? Function()? photoPath,
  }) {
    return BabyProfile(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // UserProvider 접근용
import 'generated/l10n.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _armLengthController = TextEditingController();
  final TextEditingController _forearmLengthController = TextEditingController();
  
  String _selectedGender = 'Male';
  String _selectedArm = 'Right';
  bool _showUserList = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 성별 변환 함수
  String _getLocalizedGender(String gender, AppLocalizations loc) {
    switch (gender) {
      case 'Male': return loc.male;
      case 'Female': return loc.female;
      case 'Other': return loc.other;
      default: return gender;
    }
  }

  // 팔 방향 변환 함수
  String _getLocalizedArm(String arm, AppLocalizations loc) {
    switch (arm) {
      case 'Right': return loc.right;
      case 'Left': return loc.left;
      default: return arm;
    }
  }

  @override
  void initState() {
    super.initState();
    // 초기값 로드
    final user = Provider.of<UserProvider>(context, listen: false);
    _syncController(user);
  }

  // Provider 데이터와 컨트롤러 동기화
  void _syncController(UserProvider user) {
    _nameController.text = user.name;
    _selectedGender = user.gender;
    _ageController.text = user.age.toString();
    _heightController.text = user.height.toString();
    _weightController.text = user.weight.toString();
    _selectedArm = user.arm;
    _armLengthController.text = user.armLength.toString(); // Provider에 armLength 필드 필요
    _forearmLengthController.text = user.forearmLength.toString();
  }

  // 클릭 시 텍스트 전체 선택
  void _selectAll(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  // 사용자 삭제 확인 팝업
  void _confirmDelete(BuildContext context, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteUser),
        content: Text("'$userName' ${AppLocalizations.of(context)!.deleteUserConfirm}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () {
              context.read<UserProvider>().deleteUser(userName);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.deleted)));
            },
            child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveData() {
    if (_formKey.currentState!.validate()) {
      Provider.of<UserProvider>(context, listen: false).saveUser(
        _nameController.text,
        _selectedGender,
        double.tryParse(_ageController.text) ?? 0.0,
        double.tryParse(_heightController.text) ?? 0.0,
        double.tryParse(_weightController.text) ?? 0.0,
        _selectedArm,
        double.tryParse(_armLengthController.text) ?? 0.0,
        double.tryParse(_forearmLengthController.text) ?? 0.0,
        _passwordController.text,
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Information saved with password!')),
      // );
      // 기존 SnackBar 대신 팝업(Dialog)을 띄우는 코드
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            // title: const Text('저장 완료'),
            // content: const Text('Information saved with password!'),
            title: Text(AppLocalizations.of(context)!.saveComplete),
            content: Text(AppLocalizations.of(context)!.informationSaved),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 팝업 창 닫기
                },
                // child: const Text('확인'),
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          );
        },
      );
      _passwordController.clear();
    }
  }

  void _showPasswordDialog(String userName, Map<String, dynamic> userData) {
    final TextEditingController _pwConfirmController = TextEditingController();
  
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$userName ${AppLocalizations.of(context)!.loadUserInfo}'),
        content: TextField(
          controller: _pwConfirmController,
          obscureText: true,
          decoration: InputDecoration(hintText: AppLocalizations.of(context)!.enterPwd),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () {
              if (_pwConfirmController.text == userData['password']) {
                context.read<UserProvider>().loadUser(userData);
                setState(() {
                  _syncController(context.read<UserProvider>());
                  _showUserList = false; // 불러온 후 리스트 닫기
                });
                Navigator.pop(context);
              // } else {
              //   // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 틀렸습니다.')));
              //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.incorrectPassword)));
              // }
              } else {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          // Text('알림'), 
                        ],
                      ),
                      content: Text(
                        AppLocalizations.of(context)!.incorrectPassword,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // 팝업 닫기
                          },
                          child: Text(AppLocalizations.of(context)!.confirm, style: TextStyle(fontSize: 16.0)),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  void _showUserListDialog(Map<String, dynamic> savedUsers) {
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          title: Text(loc.userList, style: const TextStyle(fontWeight: FontWeight.bold)),
          // 태블릿 화면에 맞게 팝업의 크기를 제한 (가로 400, 세로 400)
          content: SizedBox(
            width: 400,
            height: 400,
            child: savedUsers.isEmpty
                ? Center(
                    child: Text(
                      loc.noUserList,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder( // 상하 스크롤을 지원하는 리스트뷰
                    shrinkWrap: true,
                    itemCount: savedUsers.keys.length,
                    itemBuilder: (context, index) {
                      String userName = savedUsers.keys.elementAt(index);
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(userName, style: const TextStyle(fontSize: 18.0)), // 태블릿을 위한 큰 폰트
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16), // 선택 가능하다는 시각적 단서
                          onTap: () {
                            // 1. 유저 리스트 팝업 닫기
                            Navigator.of(context).pop();
                            // 2. 선택한 유저의 비밀번호 입력 팝업 띄우기
                            _showPasswordDialog(userName, savedUsers[userName]!);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 팝업 닫기
              },
              child: Text(loc.cancel ?? '취소', style: const TextStyle(fontSize: 16.0)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final userProvider = context.watch<UserProvider>();
    final savedUsers = userProvider.allSavedUsers;

    return Scaffold(
      appBar: AppBar(title: Text(loc.userInfoEntry)),
      body: Row(
        children: [
          // [왼쪽 패널] 입력 폼 영역
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 불러오기 리스트 영역
                      if (_showUserList) ...[
                        Text(loc.userList, style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (savedUsers.isEmpty)
                          Text(loc.noUserList, style: TextStyle(color: Colors.grey, fontSize: 12))
                        else
                          Wrap(
                            spacing: 8,
                            children: savedUsers.keys.map((userName) {
                              return ActionChip(
                                avatar: const Icon(Icons.person, size: 16),
                                label: Text(userName),
                                onPressed: () => _showPasswordDialog(userName, savedUsers[userName]!),
                              );
                            }).toList(),
                          ),
                        const Divider(height: 30),
                      ],
                      
                      // 1. Name (selectAll 적용)
                      TextFormField(
                        controller: _nameController, 
                        decoration: InputDecoration(labelText: loc.name, border: const OutlineInputBorder()),
                        onTap: () => _selectAll(_nameController), 
                      ),
                      const SizedBox(height: 10),

                      // 2. Gender (복원됨)
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(labelText: loc.gender, border: const OutlineInputBorder()),
                        // items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        items: [
                          DropdownMenuItem(value: 'Male', child: Text(loc.male)),
                          DropdownMenuItem(value: 'Female', child: Text(loc.female)),
                          DropdownMenuItem(value: 'Other', child: Text(loc.other)),
                        ],
                        onChanged: (v) => setState(() => _selectedGender = v!),
                      ),
                      const SizedBox(height: 10),

                      // 3. Age (selectAll 적용)
                      TextFormField(controller: _ageController, decoration: InputDecoration(labelText: loc.age, border: const OutlineInputBorder()), keyboardType: TextInputType.number, onTap: () => _selectAll(_ageController)),
                      const SizedBox(height: 10),

                      // 4. Height (selectAll 적용)
                      TextFormField(controller: _heightController, decoration: InputDecoration(labelText: loc.height, border: const OutlineInputBorder()), keyboardType: TextInputType.number, onTap: () => _selectAll(_heightController)),
                      const SizedBox(height: 10),

                      // 5. Weight (selectAll 적용)
                      TextFormField(controller: _weightController, decoration: InputDecoration(labelText: loc.weight, border: const OutlineInputBorder()), keyboardType: TextInputType.number, onTap: () => _selectAll(_weightController)),
                      const SizedBox(height: 10),

                      // 6. Diseased Arm (복원됨)
                      DropdownButtonFormField<String>(
                        value: _selectedArm,
                        decoration: InputDecoration(labelText: loc.diseasedArm, border: const OutlineInputBorder()),
                        // items: ['Right', 'Left'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        items: [
                          DropdownMenuItem(value: 'Right', child: Text(loc.right)),
                          DropdownMenuItem(value: 'Left', child: Text(loc.left)),
                        ],
                        onChanged: (v) => setState(() => _selectedArm = v!),
                      ),
                      const SizedBox(height: 10),

                      // 팔 길이 추가
                      // const SizedBox(height: 10),
                      TextFormField(
                        controller: _armLengthController,
                        decoration: InputDecoration(labelText: loc.armLength, border: const OutlineInputBorder()), // loc.armLength 등으로 대체 가능
                        keyboardType: TextInputType.number,
                        onTap: () => _selectAll(_armLengthController),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _forearmLengthController,
                        decoration: InputDecoration(labelText: loc.forearmLength, border: const OutlineInputBorder()), // loc.forearmLength 등으로 대체 가능
                        keyboardType: TextInputType.number,
                        onTap: () => _selectAll(_forearmLengthController),
                      ),
                      const SizedBox(height: 10),

                      // 7. Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: loc.passwordToSave, border: const OutlineInputBorder(), fillColor: Colors.yellow, filled: true),
                      ),
                      const SizedBox(height: 20),

                      // 버튼 영역
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     ElevatedButton(onPressed: _saveData, child: Text(loc.saveInformation)),
                      //     const SizedBox(width: 10),
                      //     ElevatedButton(
                      //       onPressed: () => setState(() => _showUserList = !_showUserList),
                      //       style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      //       child: Text(_showUserList ? loc.close : loc.loadUser),
                      //     ),
                      //   ],
                      // ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _saveData, 
                            child: Text(loc.saveInformation), // '정보 저장' 버튼
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              // 기존의 setState 토글 방식을 지우고, 바로 팝업 함수를 호출합니다.
                              _showUserListDialog(savedUsers); 
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey, 
                              foregroundColor: Colors.white,
                            ),
                            // 팝업으로 처리되므로 텍스트가 바뀔 필요 없이 항상 '불러오기(loadUser)'로 고정합니다.
                            child: Text(loc.loadUser), 
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(),

          // [오른쪽 패널] Current User 영역 (요청하신 디자인 반영)
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 간격 밀착
              children: [
                Text(loc.currentUser, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15), // 간격 줄임
                
                // 사용자 정보 표시 (Gender, Arm 포함 전체 복원)
                Text('${loc.name}: ${userProvider.name}', style: const TextStyle(fontSize: 18, color: Colors.blue)),
                const SizedBox(height: 5),
                // Text('${loc.gender}: ${userProvider.gender}'),
                Text('${loc.gender}: ${_getLocalizedGender(userProvider.gender, loc)}'),
                const SizedBox(height: 5),
                Text('${loc.age}: ${userProvider.age}'),
                const SizedBox(height: 5),
                Text('${loc.height}: ${userProvider.height} m'),
                const SizedBox(height: 5),
                Text('${loc.weight}: ${userProvider.weight} kg'),
                const SizedBox(height: 5),
                // Text('${loc.diseasedArm}: ${userProvider.arm}'), // 복원됨
                Text('${loc.diseasedArm}: ${_getLocalizedArm(userProvider.arm, loc)}'),

                // Weight 표시 텍스트 아래에 추가
                const SizedBox(height: 5),
                Text('${loc.armLength}: ${userProvider.armLength} cm'),
                const SizedBox(height: 5),
                Text('${loc.forearmLength}: ${userProvider.forearmLength} cm'),
                
                const SizedBox(height: 25), // 정보와 휴지통 사이 간격
                
                // 휴지통 아이콘 (문구 없이 아이콘만 표시)
                if (userProvider.name != "N/A" && userProvider.name.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red, size: 40),
                    onPressed: () => _confirmDelete(context, userProvider.name),
                    tooltip: 'Delete User',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
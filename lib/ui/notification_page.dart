import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationInboxPage extends StatefulWidget {
  final List<Map<String, String>> notifications;
  final VoidCallback onClearAll;
  final Function(int) onDelete;

  const NotificationInboxPage({
    super.key,
    required this.notifications,
    required this.onClearAll,
    required this.onDelete,
  });

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  String _searchQuery = "";
  String _filterType = "الكل";

  @override
  Widget build(BuildContext context) {
    // تصفية القائمة بناءً على البحث والنوع
    final filteredList = widget.notifications.where((notif) {
      final matchesSearch = notif['message']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _filterType == "الكل" || notif['type'] == _filterType;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // خلفية هادئة للعين
      appBar: AppBar(
        elevation: 0,
        title: const Text("صندوق الإشعارات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade900,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 28),
              onPressed: _confirmClearAll,
              tooltip: "مسح الكل",
            )
        ],
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return _buildNotificationItem(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // الجزء العلوي: البحث والفلاتر
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: "بحث في الرسائل...",
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, color: Colors.blue),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("الكل", Icons.all_inclusive),
                _filterChip("alert", Icons.warning_amber_rounded, label: "تنبيهات خطيرة"),
                _filterChip("status", Icons.info_outline, label: "حالات النظام"),
                _filterChip("location", Icons.location_on_outlined, label: "مواقع"),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // تصميم بطاقة الإشعار المفردة مع ميزة السحب للحذف
  Widget _buildNotificationItem(Map<String, String> item) {
    bool isAlert = item['type'] == 'alert';
    int originalIndex = widget.notifications.indexOf(item);

    return Dismissible(
      key: Key(item['id'] ?? item.hashCode.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
      ),
      onDismissed: (direction) {
        widget.onDelete(originalIndex);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الإشعار"), duration: Duration(seconds: 1)));
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: isAlert ? BorderSide(color: Colors.red.shade200, width: 1) : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAlert ? Colors.red.shade50 : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAlert ? Icons.priority_high_rounded : Icons.notifications_none_rounded,
              color: isAlert ? Colors.red : Colors.blue.shade800,
            ),
          ),
          title: Text(
            item['message'] ?? "",
            style: TextStyle(
              fontWeight: isAlert ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
              color: isAlert ? Colors.red.shade900 : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(item['time'] ?? "", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          onTap: () {
            if (item['lat'] != null && item['lat'] != "" && item['lat'] != "null") {
              launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${item['lat']},${item['lng']}"));
            }
          },
          trailing: item['lat'] != null && item['lat'] != "" && item['lat'] != "null"
              ? const Icon(Icons.map_outlined, color: Colors.green)
              : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ),
      ),
    );
  }

  // تصميم الفلاتر (Chips)
  Widget _filterChip(String type, IconData icon, {String? label}) {
    bool isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.blue.shade900),
        label: Text(label ?? type),
        selected: isSelected,
        onSelected: (s) => setState(() => _filterType = s ? type : "الكل"),
        selectedColor: Colors.blue.shade700,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blue.shade900, fontWeight: FontWeight.bold),
        elevation: 2,
        pressElevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  // حالة عدم وجود بيانات
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(_searchQuery.isEmpty ? "لا توجد إشعارات حالياً" : "لم يتم العثور على نتائج للبحث", 
               style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  // تأكيد مسح الكل
  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.delete_sweep, color: Colors.red), SizedBox(width: 10), Text("حذف الكل")],
        ),
        content: const Text("سيتم مسح جميع الإشعارات المخزنة، هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              widget.onClearAll();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text("نعم، احذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
// ############################################################
// صفحة صندوق الإشعارات المطورة (البحث والفلترة)
// ############################################################
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
    final filteredList = widget.notifications.where((notif) {
      final matchesSearch = notif['message']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _filterType == "الكل" || notif['type'] == _filterType;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
     appBar: AppBar(
  title: const Text("صندوق الإشعارات", style: TextStyle(color: Colors.white)),
  backgroundColor: Colors.blue.shade900,
  iconTheme: const IconThemeData(color: Colors.white), // يجعل سهم العودة أبيض
  actions: [
    IconButton(
      icon: const Icon(Icons.delete_sweep, color: Colors.white), // اللون الأبيض هنا
      onPressed: () {
        // إضافة تأكيد قبل الحذف (اختياري لكنه احترافي)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("حذف الكل"),
            content: const Text("هل أنت متأكد من حذف جميع الإشعارات؟"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              TextButton(
                onPressed: () {
                  widget.onClearAll(); // استدعاء دالة الحذف الأصلية
                  setState(() {}); // <--- هذا السطر هو السر، سيقوم بتحديث الصفحة فوراً لتظهر فارغة
                  Navigator.pop(context);
                },
                child: const Text("حذف", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      tooltip: "مسح الكل",
    )
  ],
),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "بحث في التنبيهات...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true, fillColor: Colors.grey.shade100,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("الكل"),
                _filterChip("alert", label: "تنبيهات خطيرة"),
                _filterChip("status", label: "حالات النظام"),
                _filterChip("location", label: "مواقع"),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("لا توجد إشعارات تطابق بحثك"))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      bool isAlert = item['type'] == 'alert';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        shape: RoundedRectangleBorder(
                          side: isAlert ? const BorderSide(color: Colors.red, width: 1) : BorderSide.none,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAlert ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(isAlert ? Icons.warning : Icons.info, color: isAlert ? Colors.red : Colors.blue),
                          ),
                          title: Text(item['message'] ?? "", style: TextStyle(fontWeight: isAlert ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text(item['time'] ?? ""),
                          onTap: () {
                            if (item['lat'] != "" && item['lat'] != "null") {
                              launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${item['lat']},${item['lng']}"));
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              int originalIndex = widget.notifications.indexOf(item);
                              widget.onDelete(originalIndex);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String type, {String? label}) {
    bool isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(label ?? type),
        selected: isSelected,
        onSelected: (s) => setState(() => _filterType = s ? type : "الكل"),
        selectedColor: Colors.blue.shade900,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }
}
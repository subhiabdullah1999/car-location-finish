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
    // التحقق من حالة الثيم
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredList = widget.notifications.where((notif) {
      final matchesSearch = notif['message']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _filterType == "الكل" || notif['type'] == _filterType;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      // خلفية تتغير حسب الوضع
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: const Text("صندوق الإشعارات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.blue.shade900,
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
          _buildHeaderSection(isDark),
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return _buildNotificationItem(item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.blue.shade900,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          TextField(
            // لون الخط داخل البحث
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "بحث في الرسائل...",
              hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue.shade300 : Colors.blue),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
                _filterChip("الكل", Icons.all_inclusive, isDark),
                _filterChip("alert", Icons.warning_amber_rounded, label: "تنبيهات خطيرة", isDark),
                _filterChip("status", Icons.info_outline, label: "حالات النظام", isDark),
                _filterChip("location", Icons.location_on_outlined, label: "مواقع", isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, String> item, bool isDark) {
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // لون الكرت
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: isAlert ? BorderSide(color: isDark ? Colors.red.withOpacity(0.5) : Colors.red.shade200, width: 1) : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAlert 
                  ? (isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50) 
                  : (isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAlert ? Icons.priority_high_rounded : Icons.notifications_none_rounded,
              color: isAlert ? Colors.red : (isDark ? Colors.blue.shade300 : Colors.blue.shade800),
            ),
          ),
          title: Text(
            item['message'] ?? "",
            style: TextStyle(
              fontWeight: isAlert ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
              // لون الخط أبيض في الدارك مود
              color: isAlert 
                  ? (isDark ? Colors.redAccent : Colors.red.shade900) 
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(item['time'] ?? "", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12)),
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
              : Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white54 : Colors.grey),
        ),
      ),
    );
  }

  Widget _filterChip(String type, IconData icon, bool isDark, {String? label}) {
    bool isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : (isDark ? Colors.blue.shade300 : Colors.blue.shade900)),
        label: Text(label ?? type),
        selected: isSelected,
        onSelected: (s) => setState(() => _filterType = s ? type : "الكل"),
        selectedColor: Colors.blue.shade700,
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.blue.shade100 : Colors.blue.shade900), 
          fontWeight: FontWeight.bold
        ),
        elevation: 2,
        pressElevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(_searchQuery.isEmpty ? "لا توجد إشعارات حالياً" : "لم يتم العثور على نتائج للبحث", 
               style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

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
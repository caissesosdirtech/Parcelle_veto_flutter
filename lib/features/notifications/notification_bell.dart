import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class NotificationBellWidget extends StatefulWidget {
  final Dio dio; // Votre instance Dio configurée pour pointer vers votre serveur Django
  const NotificationBellWidget({super.key, required this.dio});

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  int _nonLues = 0;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
  }

  // 1. Récupérer les notifications et le compteur depuis l'API Django
  Future<void> _chargerNotifications() async {
    try {
      final response = await widget.dio.get("notifications/api/notifications/");
      if (mounted) {
        setState(() {
          _nonLues = response.data['non_lues'] ?? 0;
          _notifications = response.data['results'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement des notifications : $e");
    }
  }

  // 2. Marquer toutes les notifications comme lues et actualiser le badge
  Future<void> _marquerCommeLues() async {
    try {
      await widget.dio.post("notifications/api/notifications/marquer-lues/");
      if (mounted) {
        setState(() {
          _nonLues = 0;
          // Mettre à jour localement l'état "lue" dans la liste
          for (var notif in _notifications) {
            notif['lue'] = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour des notifications : $e");
    }
  }

  // 3. Ouvrir le panneau d'historique (BottomSheet)
  Future<void> _ouvrirPanneauNotifications(BuildContext context) async {
    // Recharge la liste pour afficher les dernières notifications du serveur
    await _chargerNotifications();
    if (!context.mounted) return;
    _marquerCommeLues(); // Efface le point rouge dès l'ouverture

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Barre de titre du panneau
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Centre de Notifications",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Liste des notifications
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(
                  child: Text(
                    "Aucune notification pour le moment.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    return ListTile(
                      leading: _getIconByType(notif['type_action']),
                      title: Text(
                        notif['titre'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notif['message'] ?? ''),
                          const SizedBox(height: 4),
                          Text(
                            notif['date'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Icône dynamique selon le type d'action (vente, stock, consultation, rdv)
  Widget _getIconByType(String? type) {
    switch (type) {
      case 'vente':
        return const CircleAvatar(
          backgroundColor: Color(0xFFC8E6C9), // vert clair (green.shade100)
          child: Icon(Icons.shopping_cart, color: Colors.green),
        );
      case 'stock':
        return const CircleAvatar(
          backgroundColor: Color(0xFFFFCDD2), // rouge clair (red.shade100)
          child: Icon(Icons.warning, color: Colors.red),
        );
      case 'consultation':
        return const CircleAvatar(
          backgroundColor: Color(0xFFBBDEFB), // bleu clair (blue.shade100)
          child: Icon(Icons.medical_services, color: Colors.blue),
        );
      case 'rdv':
        return const CircleAvatar(
          backgroundColor: Color(0xFFFFE0B2), // orange clair (orange.shade100)
          child: Icon(Icons.calendar_today, color: Colors.orange),
        );
      case 'compte':
        return const CircleAvatar(
          backgroundColor: Color(0xFFEDE9FE), // violet clair
          child: Icon(Icons.key_rounded, color: Color(0xFF7C3AED)),
        );
      default:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.notifications, color: Colors.white),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => _ouvrirPanneauNotifications(context),
        ),
        if (_nonLues > 0)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                '$_nonLues',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
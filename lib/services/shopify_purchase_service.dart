import 'package:dio/dio.dart';

/// Service to check if a user has purchased "Fat Burner" via Shopify.
/// DIRECT FRONTEND FALLBACK CALL
class ShopifyPurchaseService {
  ShopifyPurchaseService._();
  static final ShopifyPurchaseService instance = ShopifyPurchaseService._();

  final _dio = Dio();

  // SHOPIFY CREDENTIALS (FRONTEND FALLBACK)
  final String _shopDomain = 'betteralt-dev.myshopify.com';
  final String _accessToken = 'shpat_PLACEHOLDER_SECRET_TOKEN';
  final String _productName = 'Fat Burner';

  /// Performs the GraphQL Request
  Future<Map<String, dynamic>> _shopifyGraphQL(
      String query, Map<String, dynamic> variables) async {
    final url = 'https://$_shopDomain/admin/api/2024-01/graphql.json';
    try {
      final response = await _dio.post(
        url,
        data: {'query': query, 'variables': variables},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Shopify-Access-Token': _accessToken,
          },
        ),
      );

      final data = response.data;
      if (data['errors'] != null) {
        throw Exception("Shopify API Error: ${data['errors']}");
      }
      return data['data'] ?? {};
    } catch (e) {
      throw Exception("Shopify Request Failed: $e");
    }
  }

  /// Checks if Fat Burner exists in a given order node
  bool _hasFatBurnerInOrder(Map<String, dynamic> orderNode) {
    try {
      final edges = orderNode['lineItems']['edges'] as List;
      for (var edge in edges) {
        final title = (edge['node']?['title'] as String?)?.toLowerCase() ?? '';
        if (title.contains(_productName.toLowerCase())) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Look up orders directly by email
  Future<bool> _checkByEmail(String email) async {
    const String query = """
      query GetOrdersByEmail(\$query: String!) {
        orders(first: 50, query: \$query) {
          edges {
            node {
              id
              lineItems(first: 100) {
                edges {
                  node {
                    title
                  }
                }
              }
            }
          }
        }
      }
    """;

    final escapedEmail = email.replaceAll('"', '\\"');
    final searchQuery = 'email:"$escapedEmail"';

    final data = await _shopifyGraphQL(query, {'query': searchQuery});
    final edges = data['orders']?['edges'] as List? ?? [];

    for (var edge in edges) {
      if (_hasFatBurnerInOrder(edge['node'] ?? {})) {
        return true;
      }
    }
    return false;
  }

  /// Look up orders directly by phone
  Future<bool> _checkByPhone(String phone) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final robustPhone = normalizedPhone.length >= 10 
        ? normalizedPhone.substring(normalizedPhone.length - 10) 
        : normalizedPhone;

    if (robustPhone.isEmpty) return false;

    // 1. Fetch Customer ID (Shopify fully supports 'phone' queries here)
    const String customersQuery = """
      query GetCustomerByPhone(\$query: String!) {
        customers(first: 10, query: \$query) {
          edges {
            node {
              id
            }
          }
        }
      }
    """;

    final cusData = await _shopifyGraphQL(
        customersQuery, {'query': 'phone:*$robustPhone*'});
    final cusEdges = cusData['customers']?['edges'] as List? ?? [];
    if (cusEdges.isEmpty) return false;

    final customerId = cusEdges.first['node']?['id'] as String? ?? '';
    final numericId = customerId.replaceAll(RegExp(r'\D'), '');

    if (numericId.isEmpty) return false;

    // 2. Fetch Orders for Customer ID
    const String ordersQuery = """
      query GetOrdersByCustomerId(\$query: String!) {
        orders(first: 50, query: \$query) {
          edges {
            node {
              id
              lineItems(first: 100) {
                edges {
                  node {
                    title
                  }
                }
              }
            }
          }
        }
      }
    """;

    final ordData = await _shopifyGraphQL(
        ordersQuery, {'query': 'customer_id:$numericId'});
    final ordEdges = ordData['orders']?['edges'] as List? ?? [];

    for (var edge in ordEdges) {
      if (_hasFatBurnerInOrder(edge['node'] ?? {})) {
        return true;
      }
    }
    return false;
  }

  /// Checks if the user has purchased "Fat Burner".
  Future<bool> hasPurchasedFatBurner({
    String? email,
    String? phone,
  }) async {
    if ((email == null || email.trim().isEmpty) &&
        (phone == null || phone.trim().isEmpty)) {
      throw ArgumentError('Provide at least one of: email, phone');
    }

    if (email != null && email.trim().isNotEmpty) {
      final success = await _checkByEmail(email.trim());
      if (success) return true;
    }

    if (phone != null && phone.trim().isNotEmpty) {
      final success = await _checkByPhone(phone.trim());
      if (success) return true;
    }

    return false;
  }
}

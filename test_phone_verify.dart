import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final shopDomain = 'betteralt-dev.myshopify.com';
  final accessToken = 'shpat_PLACEHOLDER_SECRET_TOKEN';

  Future<Map<String, dynamic>> _shopifyGraphQL(String query, Map<String, dynamic> variables) async {
    final url = Uri.parse('https://$shopDomain/admin/api/2024-01/graphql.json');
    final request = await HttpClient().postUrl(url);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('X-Shopify-Access-Token', accessToken);

    request.write(jsonEncode({'query': query, 'variables': variables}));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return jsonDecode(responseBody)['data'] ?? {};
  }

  bool _hasFatBurnerInOrder(Map<String, dynamic> orderNode) {
    try {
      final edges = orderNode['lineItems']['edges'] as List;
      for (var edge in edges) {
        final title = (edge['node']?['title'] as String?)?.toLowerCase() ?? '';
        if (title.contains('fat burner')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // TEST PHONE LOGIC
  String phone = '6280426194';
  final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
  final robustPhone = normalizedPhone.length >= 10 
      ? normalizedPhone.substring(normalizedPhone.length - 10) 
      : normalizedPhone;
  
  print("Robust phone: $robustPhone");

  const String customersQuery = """
    query GetCustomerByPhone(\$query: String!) {
      customers(first: 10, query: \$query) {
        edges {
          node {
            id
            phone
          }
        }
      }
    }
  """;

  final cusData = await _shopifyGraphQL(
      customersQuery, {'query': 'phone:*$robustPhone*'});
  print("Customer Data: " + jsonEncode(cusData));

  final cusEdges = cusData['customers']?['edges'] as List? ?? [];
  if (cusEdges.isEmpty) {
    print("NO CUSTOMER FOUND FOR PHONE: $phone");
    return;
  }

  final customerId = cusEdges.first['node']?['id'] as String? ?? '';
  final numericId = customerId.replaceAll(RegExp(r'\D'), '');
  print("Found numeric ID: $numericId");

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
  print("Orders Data: " + jsonEncode(ordData));

  final ordEdges = ordData['orders']?['edges'] as List? ?? [];

  bool found = false;
  for (var edge in ordEdges) {
    if (_hasFatBurnerInOrder(edge['node'] ?? {})) {
      found = true;
      break;
    }
  }

  print("FINAL RESULT phone: $found");
}

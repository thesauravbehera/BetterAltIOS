import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final shopDomain = 'betteralt-dev.myshopify.com';
  final accessToken = 'shpat_PLACEHOLDER_SECRET_TOKEN';
  final robustPhone = '6280426194'; // From user's previous complaints

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

  final url = Uri.parse('https://$shopDomain/admin/api/2024-01/graphql.json');
  final request = await HttpClient().postUrl(url);
  request.headers.set('Content-Type', 'application/json');
  request.headers.set('X-Shopify-Access-Token', accessToken);

  request.write(jsonEncode({
    'query': customersQuery,
    'variables': {'query': 'phone:*$robustPhone*'}
  }));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print("Customer Response: " + responseBody);

  final parsed = jsonDecode(responseBody);
  final cusEdges = parsed['data']?['customers']?['edges'] as List? ?? [];
  if (cusEdges.isEmpty) {
    print("No customer found!");
    return;
  }
  
  final customerId = cusEdges.first['node']?['id'] as String? ?? '';
  final numericId = customerId.replaceAll(RegExp(r'\D'), '');
  print("Found Customer ID: " + numericId);

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

  final request2 = await HttpClient().postUrl(url);
  request2.headers.set('Content-Type', 'application/json');
  request2.headers.set('X-Shopify-Access-Token', accessToken);

  request2.write(jsonEncode({
    'query': ordersQuery,
    'variables': {'query': 'customer_id:$numericId'}
  }));

  final response2 = await request2.close();
  final responseBody2 = await response2.transform(utf8.decoder).join();
  print("Orders Response: " + responseBody2);
}

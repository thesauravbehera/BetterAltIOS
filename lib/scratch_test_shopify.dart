import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final shopDomain = 'betteralt-dev.myshopify.com';
  final accessToken = 'shpat_PLACEHOLDER_SECRET_TOKEN';

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
    'variables': {'query': 'phone:*6280426194*'}
  }));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print("Response Match: " + responseBody);
}

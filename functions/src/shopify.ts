/**
 * Shopify Admin API client.
 * Credentials are passed in - never hardcoded.
 */

const SHOPIFY_API_VERSION = '2024-01';
const FAT_BURNER_PRODUCT_NAME = 'Fat Burner';

export interface ShopifyConfig {
  shopDomain: string;
  accessToken: string;
}

interface ShopifyGraphQLResponse<T> {
  data?: T;
  errors?: Array<{ message: string }>;
}

interface OrderNode {
  id: string;
  lineItems: {
    edges: Array<{
      node: {
        title: string;
      };
    }>;
  };
}

interface OrdersQueryResult {
  orders: {
    edges: Array<{ node: OrderNode }>;
    pageInfo: {
      hasNextPage: boolean;
      endCursor: string | null;
    };
  };
}

interface CustomerNode {
  id: string;
}

interface CustomersQueryResult {
  customers: {
    edges: Array<{ node: CustomerNode }>;
  };
}

async function shopifyGraphQL<T>(
  config: ShopifyConfig,
  query: string,
  variables?: Record<string, unknown>
): Promise<T> {
  const url = `https://${config.shopDomain}/admin/api/${SHOPIFY_API_VERSION}/graphql.json`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': config.accessToken,
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!response.ok) {
    throw new Error(`Shopify API request failed: ${response.status} ${response.statusText}`);
  }

  const json = (await response.json()) as ShopifyGraphQLResponse<T>;

  if (json.errors?.length) {
    throw new Error(`Shopify API error: ${json.errors.map((e) => e.message).join(', ')}`);
  }

  if (!json.data) {
    throw new Error('Shopify API returned no data');
  }

  return json.data;
}

function hasFatBurnerInOrder(order: OrderNode): boolean {
  const productNameLower = FAT_BURNER_PRODUCT_NAME.toLowerCase();

  for (const edge of order.lineItems.edges) {
    const title = edge.node.title?.toLowerCase() ?? '';
    if (title.includes(productNameLower)) {
      return true;
    }
  }
  return false;
}

async function fetchOrdersByEmail(config: ShopifyConfig, email: string): Promise<OrderNode[]> {
  const orders: OrderNode[] = [];
  let cursor: string | null = null;

  const query = `
    query GetOrdersByEmail($query: String!, $cursor: String) {
      orders(first: 50, query: $query, after: $cursor) {
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
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  `;

  do {
    const escapedEmail = email.replace(/"/g, '\\"');
    const searchQuery = `email:"${escapedEmail}"`;

    const resultData: OrdersQueryResult = await shopifyGraphQL<OrdersQueryResult>(config, query, {
      query: searchQuery,
      cursor,
    });

    for (const edge of resultData.orders.edges) {
      orders.push(edge.node);
    }

    cursor = resultData.orders.pageInfo.hasNextPage ? resultData.orders.pageInfo.endCursor : null;
  } while (cursor);

  return orders;
}

async function fetchOrdersByPhone(config: ShopifyConfig, phone: string): Promise<OrderNode[]> {
  const normalizedPhone = phone.replace(/\D/g, '');
  if (!normalizedPhone) {
    return [];
  }

  const customersQuery = `
    query GetCustomerByPhone($query: String!) {
      customers(first: 1, query: $query) {
        edges {
          node {
            id
          }
        }
      }
    }
  `;

  const customerData = await shopifyGraphQL<CustomersQueryResult>(config, customersQuery, {
    query: `phone:*${normalizedPhone}*`,
  });

  const customer = customerData.customers.edges[0]?.node;
  if (!customer) {
    return [];
  }

  const numericId = customer.id.replace(/\D/g, '');
  const orders: OrderNode[] = [];
  let cursor: string | null = null;

  const ordersQuery = `
    query GetOrdersByCustomerId($query: String!, $cursor: String) {
      orders(first: 50, query: $query, after: $cursor) {
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
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  `;

  do {
    const resultData: OrdersQueryResult = await shopifyGraphQL<OrdersQueryResult>(config, ordersQuery, {
      query: `customer_id:${numericId}`,
      cursor,
    });

    for (const edge of resultData.orders.edges) {
      orders.push(edge.node);
    }

    cursor = resultData.orders.pageInfo.hasNextPage ? resultData.orders.pageInfo.endCursor : null;
  } while (cursor);

  return orders;
}

/**
 * Checks if the user has purchased "Fat Burner" by email or phone.
 */
export async function hasPurchasedFatBurner(
  config: ShopifyConfig,
  email?: string,
  phone?: string
): Promise<boolean> {
  if (!email && !phone) {
    return false;
  }

  let orders: OrderNode[] = [];

  if (email) {
    orders = await fetchOrdersByEmail(config, email);
  }

  if (orders.length === 0 && phone) {
    orders = await fetchOrdersByPhone(config, phone);
  }

  for (const order of orders) {
    if (hasFatBurnerInOrder(order)) {
      return true;
    }
  }

  return false;
}

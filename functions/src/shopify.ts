/**
 * Shopify Admin API client.
 * Credentials are passed in - never hardcoded.
 */

const SHOPIFY_API_VERSION = '2024-01';
const FAT_BURNER_PRODUCT_NAME = 'Fat Burner';

export interface ShopifyConfig {
  shopDomain: string;
  clientId: string;
  clientSecret: string;
}

let cachedAccessToken: string | null = null;
let tokenExpiryTime: number = 0;

async function getAccessToken(config: ShopifyConfig): Promise<string> {
  const now = Date.now();
  
  // Reuse token if it is valid (with 5 min buffer 23h 55m)
  if (cachedAccessToken && now < tokenExpiryTime) {
    return cachedAccessToken;
  }

  console.log(`[Shopify] Fetching fresh 24-hr access token...`);
  
  const url = `https://${config.shopDomain}/admin/oauth/access_token`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: config.clientId,
      client_secret: config.clientSecret,
      grant_type: 'client_credentials'
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    console.error(`[Shopify OAuth Error] ${errText}`);
    throw new Error(`Failed to generate Shopify access token: ${response.status}`);
  }

  const data = await response.json() as any;
  if (!data.access_token) {
    throw new Error('No access token returned from Shopify Client Credentials grant');
  }

  cachedAccessToken = data.access_token;
  tokenExpiryTime = now + (23 * 60 * 60 * 1000); // Expires in 24h, we cache for 23h to be safe
  
  console.log(`[Shopify] Successfully generated new access token.`);
  return cachedAccessToken as string;
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
  const token = await getAccessToken(config);
  
  const url = `https://${config.shopDomain}/admin/api/${SHOPIFY_API_VERSION}/graphql.json`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': token,
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
  if (!normalizedPhone || normalizedPhone.length < 10) {
    console.log(`[Shopify] Phone too short after normalization: "${normalizedPhone}"`);
    return [];
  }

  const last10 = normalizedPhone.slice(-10);
  const withCountryCode = `+91${last10}`;
  const formattedWithSpaces = `+91 ${last10.slice(0, 5)} ${last10.slice(5)}`;

  console.log(`[Shopify] Searching customer by phone. Raw="${phone}", last10="${last10}", formatted="${formattedWithSpaces}"`);

  const customersQuery = `
    query GetCustomerByPhone($query: String!) {
      customers(first: 5, query: $query) {
        edges {
          node {
            id
          }
        }
      }
    }
  `;

  // Shopify does NOT support OR in customer search — try each format separately
  const phoneFormats = [
    `phone:${formattedWithSpaces}`,
    `phone:${withCountryCode}`,
    `phone:${last10}`,
  ];

  let customer: CustomerNode | null = null;

  for (const searchQuery of phoneFormats) {
    console.log(`[Shopify] Trying customer search: "${searchQuery}"`);
    try {
      const customerData = await shopifyGraphQL<CustomersQueryResult>(config, customersQuery, {
        query: searchQuery,
      });
      if (customerData.customers.edges.length > 0) {
        customer = customerData.customers.edges[0].node;
        console.log(`[Shopify] Found customer via "${searchQuery}": ${customer.id}`);
        break;
      }
    } catch (err) {
      console.log(`[Shopify] Search "${searchQuery}" failed: ${err}`);
    }
  }

  // If customer search failed, try searching orders directly by phone
  if (!customer) {
    console.log(`[Shopify] No customer found. Trying direct order search by phone...`);
    return await fetchOrdersDirectlyByPhone(config, last10, formattedWithSpaces);
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

  console.log(`[Shopify] Found ${orders.length} orders for customer ${numericId}`);
  return orders;
}

/**
 * Fallback: Search orders directly by phone number if customer lookup fails.
 * Shopify orders support phone-based search queries.
 */
async function fetchOrdersDirectlyByPhone(config: ShopifyConfig, last10: string, formattedPhone: string): Promise<OrderNode[]> {
  const ordersQuery = `
    query GetOrdersByPhone($query: String!, $cursor: String) {
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

  const orders: OrderNode[] = [];

  // Try multiple phone formats for order search
  const searchQueries = [last10, formattedPhone, `+91${last10}`];

  for (const phoneQuery of searchQueries) {
    console.log(`[Shopify] Direct order search with phone: "${phoneQuery}"`);
    try {
      let cursor: string | null = null;
      do {
        const resultData: OrdersQueryResult = await shopifyGraphQL<OrdersQueryResult>(config, ordersQuery, {
          query: phoneQuery,
          cursor,
        });

        for (const edge of resultData.orders.edges) {
          orders.push(edge.node);
        }

        cursor = resultData.orders.pageInfo.hasNextPage ? resultData.orders.pageInfo.endCursor : null;
      } while (cursor);

      if (orders.length > 0) {
        console.log(`[Shopify] Found ${orders.length} orders via direct phone search: "${phoneQuery}"`);
        return orders;
      }
    } catch (err) {
      console.log(`[Shopify] Direct order search failed for "${phoneQuery}": ${err}`);
    }
  }

  console.log(`[Shopify] No orders found for any phone format`);
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
  console.log(`[Shopify] hasPurchasedFatBurner called with email="${email}", phone="${phone}"`);

  if (!email && !phone) {
    console.log(`[Shopify] No email or phone provided, returning false`);
    return false;
  }

  let orders: OrderNode[] = [];

  if (email) {
    console.log(`[Shopify] Searching by email: "${email}"`);
    orders = await fetchOrdersByEmail(config, email);
    console.log(`[Shopify] Email search returned ${orders.length} orders`);
  }

  if (orders.length === 0 && phone) {
    console.log(`[Shopify] No orders from email, searching by phone: "${phone}"`);
    orders = await fetchOrdersByPhone(config, phone);
    console.log(`[Shopify] Phone search returned ${orders.length} orders`);
  }

  for (const order of orders) {
    if (hasFatBurnerInOrder(order)) {
      console.log(`[Shopify] ✅ FOUND Fat Burner purchase in order ${order.id}`);
      return true;
    }
    // Log what line items we actually found
    const titles = order.lineItems.edges.map(e => e.node.title);
    console.log(`[Shopify] Order ${order.id} line items: ${JSON.stringify(titles)}`);
  }

  console.log(`[Shopify] ❌ No Fat Burner purchase found`);
  return false;
}

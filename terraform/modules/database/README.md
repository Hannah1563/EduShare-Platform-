# database module

Azure Cosmos DB for MongoDB (API 4.2), with the `edushare` database and the `resources` collection the app uses. The free tier is on by default (one per subscription).

The account only accepts connections from the subnets in `allowed_subnet_ids` (VNet filter with a service endpoint).

Outputs: `account_name`, `account_id`, `mongodb_connection_string` (sensitive, database name already included, ready for `MONGODB_URI`).

CrossPay
========

* * * * *

Table of Contents
-----------------

-   Introduction

-   Features

-   Error Codes

-   Constants

-   Data Maps and Variables

-   Functions

    -   Private Functions

    -   Public Functions

    -   Read-Only Functions

-   How to Use

-   Contributing

-   License

-   Contact

* * * * *

Introduction
------------

CrossPay is a decentralized remittance system built on the Stacks blockchain, designed to facilitate secure and efficient international money transfers. It supports multiple currencies, incorporates robust compliance features, and automates exchange rates, providing a transparent and cost-effective solution for global remittances.

* * * * *

Features
--------

-   **Multi-Currency Support**: Handles transfers in various major currencies (USD, EUR, GBP, JPY, STX).

-   **Automated Exchange Rates**: Utilizes predefined exchange rates for seamless currency conversion.

-   **Compliance Integration**: Includes KYC (Know Your Customer) status and compliance blocking features to meet regulatory requirements.

-   **Secure Transfers**: Ensures the integrity and security of all transactions on the blockchain.

-   **Batch Processing**: Allows for efficient processing of multiple remittances in a single transaction.

-   **Platform Fees**: A small fee is collected on transfers to support the platform's operation.

-   **Transfer Expiry**: Transfers have a defined expiry period to prevent unclaimed funds from being locked indefinitely.

* * * * *

Error Codes
-----------

| Code | Name | Description |
| :--- | :------------------------- | :------------------------------------------- |
| `u100` | `err-owner-only` | Function can only be called by the owner. |
| `u101` | `err-insufficient-balance` | Sender has insufficient balance. |
| `u102` | `err-invalid-recipient` | Recipient is invalid or same as sender. |
| `u103` | `err-transfer-not-found` | The specified transfer ID does not exist. |
| `u104` | `err-transfer-already-claimed` | The transfer has already been claimed. |
| `u105` | `err-transfer-expired` | The transfer has expired. |
| `u106` | `err-invalid-currency` | The specified currency is not supported. |
| `u107` | `err-invalid-amount` | The transfer amount is invalid. |
| `u108` | `err-kyc-required` | KYC verification is required for the user. |
| `u109` | `err-compliance-blocked` | Transaction blocked due to compliance rules. |
* * * * *

Constants
---------

-   `contract-owner`: The principal address of the contract deployer.

-   `max-transfer-amount`: `u1000000` (1,000,000 microSTX) - Maximum allowed amount for a single transfer.

-   `min-transfer-amount`: `u1000` (1,000 microSTX) - Minimum allowed amount for a single transfer.

-   `transfer-expiry-blocks`: `u1440` (approximately 24 hours) - Number of blocks after which an unclaimed transfer expires.

-   `platform-fee-rate`: `u50` (0.5% in basis points) - Fee charged on each transfer.

* * * * *

Data Maps and Variables
-----------------------

### Maps

-   `user-balances`: Stores the STX balance for each user.

    -   Type: `principal` to `uint`

-   `user-kyc-status`: Tracks the KYC verification status for each user.

    -   Type: `principal` to `bool`

-   `compliance-blocked`: Indicates if a user is blocked due to compliance reasons.

    -   Type: `principal` to `bool`

-   `currency-rates`: Stores exchange rates for supported currencies against a base (e.g., microSTX).

    -   Type: `(string-ascii 3)` to `uint` (currency code to rate in basis points)

-   `transfers`: Stores detailed information about each remittance transfer.

    -   Type: `uint` (transfer ID) to a `{ sender: principal, recipient: principal, amount: uint, currency: (string-ascii 3), exchange-rate: uint, recipient-identifier: (string-ascii 50), country-code: (string-ascii 2), purpose-code: (string-ascii 10), created-block: uint, claimed: bool, compliance-checked: bool }`

-   `user-transfer-history`: Stores a list of transfer IDs for each user (last 20 transfers).

    -   Type: `principal` to `(list 20 uint)`

### Variables

-   `next-transfer-id`: `(define-data-var next-transfer-id uint u1)` - Counter for unique transfer IDs.

-   `platform-treasury`: `(define-data-var platform-treasury uint u0)` - Accumulates platform fees.

-   `total-volume`: `(define-data-var total-volume uint u0)` - Total volume of all processed remittances.

-   `compliance-officer`: `(define-data-var compliance-officer principal contract-owner)` - Address of the compliance officer, initially set to `contract-owner`.

* * * * *

Functions
---------

### Private Functions

-   `(calculate-fee (amount uint))`: Calculates the platform fee for a given amount.

-   `(is-valid-currency (currency (string-ascii 3)))`: Checks if the provided currency is supported.

-   `(convert-currency (amount uint) (from-currency (string-ascii 3)) (to-currency (string-ascii 3)))`: Converts an amount from one currency to another using stored rates.

-   `(update-user-history (user principal) (transfer-id uint))`: Adds a transfer ID to a user's transfer history.

-   `(validate-compliance (sender principal) (recipient principal) (amount uint) (country-code (string-ascii 2)))`: Performs compliance checks before a remittance can be sent.

-   `(calculate-batch-cost (transfer-item { ... }) (accumulator uint))`: Helper function for `process-batch-remittances` to calculate total cost.

-   `(process-single-transfer (transfer-item { ... }) (transfer-ids (list 10 uint)))`: Helper function for `process-batch-remittances` to process individual transfers within a batch.

### Public Functions

-   `(deposit (amount uint))`: Allows users to deposit STX into their account balance within the contract.

-   `(withdraw (amount uint))`: Allows users to withdraw STX from their account balance.

-   `(set-kyc-status (user principal) (status bool))`: Sets the KYC status for a user (only callable by `compliance-officer`).

-   `(set-compliance-block (user principal) (blocked bool))`: Blocks or unblocks a user for compliance reasons (only callable by `compliance-officer`).

-   `(update-currency-rate (currency (string-ascii 3)) (rate uint))`: Updates the exchange rate for a specific currency (only callable by `contract-owner`).

-   `(send-remittance (recipient principal) (amount uint) (currency (string-ascii 3)) (recipient-identifier (string-ascii 50)) (country-code (string-ascii 2)) (purpose-code (string-ascii 10)))`: Initiates a single cross-border remittance.

-   `(claim-remittance (transfer-id uint))`: Allows the recipient to claim a pending remittance.

-   `(process-batch-remittances (transfers-data (list 10 { ... })))`: Processes a list of multiple remittance transfers in a single transaction. Requires sender KYC.

### Read-Only Functions

-   `(get-user-balance (user principal))`: Retrieves the current balance of a user.

-   `(get-transfer (transfer-id uint))`: Retrieves the details of a specific transfer.

-   `(get-user-kyc-status (user principal))`: Retrieves the KYC status of a user.

-   `(get-currency-rate (currency (string-ascii 3)))`: Retrieves the exchange rate for a specific currency.

-   `(get-platform-stats)`: Returns platform-wide statistics including total volume, treasury balance, and the next available transfer ID.

* * * * *

How to Use
----------

To interact with the CrossPay contract, you'll need a Stacks wallet and some STX tokens.

1.  **Deploy the Contract**: The `CrossPay` contract needs to be deployed on the Stacks blockchain.

2.  **Deposit Funds**: Users can deposit STX into the contract using the `deposit` function to fund their transfers.

3.  **Set KYC Status**: For users to send batch remittances or for compliance, a designated `compliance-officer` (initially the `contract-owner`) needs to set their KYC status using `set-kyc-status`.

4.  **Send Remittance**: Use the `send-remittance` function for individual transfers, providing recipient details, amount, currency, and compliance-related information. For bulk transfers, use `process-batch-remittances`.

5.  **Claim Remittance**: Recipients can claim their funds using the `claim-remittance` function with the unique `transfer-id`.

6.  **Manage Rates/Compliance**: The `contract-owner` can update currency exchange rates, and the `compliance-officer` can manage user compliance blocks.

* * * * *

Contributing
------------

I welcome contributions to the CrossPay project! If you're interested in improving this decentralized remittance system, please follow these steps:

1.  Fork the repository.

2.  Create a new branch for your feature or bug fix.

3.  Make your changes and ensure they are well-tested.

4.  Submit a pull request with a clear description of your changes.

* * * * *

License
-------

This project is licensed under the MIT License - see the LICENSE.md file for details.

* * * * *

Contact
-------

For any inquiries or support, please open an issue in the GitHub repository.

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title SimpleFactoring
 * @dev Implements simple factoring
 */
contract SimpleFactoring {
    address private boss; // Owner of contract
    uint8 public commision = 10; // 10% commision on invoice sales;

    struct Invoice {
        uint256 dueDate; // Deadline of payment
        address payer; // Customer
        bool settled; // If true, the invoice has been paid
        uint256 total; // Amount to be paid in Ether
        uint256 resellValue; // Invoice price in case of a sale
        uint8 resellCount; // Number of resells
    }

    mapping(address => Invoice[]) private invoices;

    struct Offer {
        Invoice invoice; // Invoice to be sold
        address payable payee; // Seller
    }

    Offer[] private offers;

    // Modifier to check if caller is owner
    modifier bossGuard {
        require(msg.sender == boss, "Caller is not the boss");
        _;
    }

    // Modifier to check if invoice is not overdue
    // Works with offer=true for Offers and offer=false for Invoices
    modifier notOverdueGuard(uint8 index, bool offer) {
        offer
            ? require(
                offers[index].invoice.dueDate != 0 &&
                    offers[index].invoice.dueDate > block.timestamp,
                "Offer does not exist or is overdue"
            )
            : require(
                invoices[msg.sender][index].dueDate != 0 &&
                    invoices[msg.sender][index].dueDate > block.timestamp,
                "Invoice does not exist or is overdue"
            );
        _;
    }

    /**
     * @dev Set contract deployer as boss
     */
    constructor() {
        boss = msg.sender;
    }

    // Boss methods

    /**
     * @dev Change commision rate
     * @param percentage New commision rate in percentage
     */
    function setCommision(uint8 percentage) public bossGuard {
        require(percentage >= 0 && percentage <= 100);
        commision = percentage;
    }

    /**
     * @dev Take out leftover Ether from contract
     */
    function getProfit() public bossGuard {
        payable(boss).transfer(address(this).balance);
    }

    // Payee methods

    /**
     * @dev Retrieves sender's invoices
     * @return User's invoices in an array
     */
    function getInvoices() public view returns (Invoice[] memory) {
        return invoices[msg.sender];
    }

    /**
     * @dev Helper function to create an invoice object
     * @param dueDate Timestamp of payment deadline
     * @param payer Address of customer
     * @param total Amount of money to be paid for the invoice in Ether
     * @param resellCount Number of resells
     * @return invoice_ The invoice object
     */
    function createInvoiceObject(
        uint256 dueDate,
        address payer,
        uint256 total,
        uint8 resellCount
    ) private view returns (Invoice memory invoice_) {
        invoice_.dueDate = dueDate;
        invoice_.payer = payer;
        invoice_.settled = false;
        invoice_.total = total;
        invoice_.resellValue = total * (1 / (commision + resellCount));
    }

    /**
     * @dev Create an invoice
     * @param dueDate Timestamp of payment deadline
     * @param payer Address of customer
     * @param total Amount of money to be paid for the invoice in Ether
     */
    function createInvoice(
        uint256 dueDate,
        address payer,
        uint256 total
    ) public {
        Invoice memory invoice = createInvoiceObject(dueDate, payer, total, 0);
        invoices[msg.sender].push(invoice);
    }

    /**
     * @dev Retrieves sender's overdue invoices length
     * @return counter_ User's overdue invoices counter
     */
    function getOverDueCount() public view returns (uint256 counter_) {
        for (uint256 i = 0; i < invoices[msg.sender].length; i++) {
            if (invoices[msg.sender][i].dueDate < block.timestamp) {
                counter_++;
            }
        }
    }

    // Payer methods

    /**
     * @dev Get all unsettled invoices
     */
    function getUnsettledInvoices() public {
        // TODO
    }

    // Market methods

    /**
     * @dev Get all offers
     * @return All offers in an array
     */
    function getOffers() public view returns (Offer[] memory) {
        return offers;
    }

    /**
     * @dev Sell an invoice
     * @param index Position of invoice within seller's invoices
     */
    function sellInvoice(uint8 index) public notOverdueGuard(index, false) {
        Offer memory offer;
        offer.invoice = invoices[msg.sender][index];
        offer.payee = payable(msg.sender);
        offers.push(offer);
        delete invoices[msg.sender][index];
    }

    /**
     * @dev Sell an invoice
     * @param index Position of invoice within seller's invoices
     */
    function buyInvoice(uint8 index)
        public
        payable
        notOverdueGuard(index, true)
    {
        Offer memory offer = offers[index];
        require(msg.value >= offer.invoice.resellValue, "Insufficient funds");
        offer.payee.transfer(offer.invoice.resellValue);
        Invoice memory invoice =
            createInvoiceObject(
                offer.invoice.dueDate,
                offer.invoice.payer,
                offer.invoice.total,
                offer.invoice.resellCount + 1
            );
        invoices[msg.sender].push(invoice);
        delete offers[index];
    }
}

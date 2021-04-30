// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title SimpleFactoring
 * @dev Implements simple factoring
 */
contract SimpleFactoring {
    address payable private boss; // Owner of contract
    uint8 public commision = 2; // 2% commision on invoice sales;

    struct Invoice {
        uint256 index; // Index of Invoice = position in array
        uint256 dueDate; // Deadline of payment
        address payer; // Customer
        bool settled; // If true, the invoice has been paid
        uint256 total; // Amount to be paid in Ether
        uint256 resellPrice; // Invoice price in case of a sale
    }

    mapping(address => Invoice[]) private invoices;
    uint256 private userCount;
    uint256 private invoiceCount;
    mapping (uint256 => address) private users;

    struct Offer {
        uint256 index; // Index of Offer = position in array
        Invoice invoice; // Invoice to be sold
        address payable seller; // Seller
    }

    Offer[] private offers;

    struct PayableInvoice {        
        Invoice invoice; // Invoice to be sold
        address payable beneficiary; // Beneficiary of the invoice
    }

    // Modifier to check if caller is owner
    modifier bossGuard {
        require(msg.sender == boss, "Caller is not the boss");
        _;
    }

    // Modifier to check if invoice is not overdue
    // Works with offer=true for Offers and offer=false for Invoices
    modifier notOverdueGuard(address sender, uint256 index, bool offer) {
        offer
            ? require(
                offers[index].invoice.dueDate != 0 &&
                    offers[index].invoice.dueDate > block.timestamp,
                "Offer does not exist or is overdue"
            )
            : require(
                invoices[sender][index].dueDate != 0 &&
                    invoices[sender][index].dueDate > block.timestamp,
                "Invoice does not exist or is overdue"
            );
        _;
    }

    // Modifier to check if invoice is settled
    // Works with offer=true for Offers and offer=false for Invoices
    modifier notSettledGuard(address sender, uint256 index, bool offer) {
        offer
            ? require(
                offers[index].invoice.dueDate != 0 &&
                    offers[index].invoice.dueDate > block.timestamp,
                "Offer does not exist or is settled"
            )
            : require(
                invoices[sender][index].dueDate != 0 &&
                    invoices[sender][index].dueDate > block.timestamp,
                "Invoice does not exist or is settled"
            );
        _;
    }
    
    // Helper methods

    /**
     * @dev Set contract deployer as boss
     */
    constructor() {
        boss = payable(msg.sender);
    }
    
     /**
     * @dev Function to create an invoice object for sender
     * @param dueDate Timestamp of payment deadline
     * @param payer Address of customer
     * @param total Amount of money to be paid for the invoice in Ether
     * @param resellPrice Selling price of invoice
     */
    function createInvoiceForSender(
        uint256 dueDate,
        address payer,
        uint256 total,
        uint256 resellPrice
    ) private {
        Invoice memory invoice;
        invoice.index = invoices[msg.sender].length;
        invoice.dueDate = dueDate;
        invoice.payer = payer;
        invoice.settled = false;
        invoice.total = total;
        invoice.resellPrice = resellPrice;
        if (invoices[msg.sender].length == 0) {
            users[userCount] = msg.sender;
            userCount++;
        }
        invoiceCount++;
        invoices[msg.sender].push(invoice);        
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
     * @dev Take out profit from contract
     */
    function getProfit() public bossGuard {
        payable(boss).transfer(address(this).balance);
    }

    // Invoice methods

    /**
     * @dev Retrieves sender's invoices
     * @return User's invoices in an array
     */
    function getInvoices() public view returns (Invoice[] memory) {
        return invoices[msg.sender];
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
        createInvoiceForSender(dueDate, payer, total, total);
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
     * @return unsettledInvoices_ User's unsettled invoices
     */
    function getUnsettledInvoices() public view returns (PayableInvoice[] memory) {
        require(false, "TODO debug");
        uint256 count = userCount * invoiceCount;
        require(count > 0, "Empty data");
        PayableInvoice[] memory unsettledInvoices = new PayableInvoice[](count);
        uint256 counter;
        for (uint256 i = 0; i < userCount; i++) {
            for (uint256 j = 0; i < invoices[users[i]].length; j++) {
                if (invoices[users[i]][j].payer == msg.sender && !invoices[users[i]][j].settled) {
                    PayableInvoice memory payableInvoice;
                    payableInvoice.invoice = invoices[users[i]][j];
                    payableInvoice.beneficiary = payable(users[i]);
                    unsettledInvoices[counter] = payableInvoice;
                    counter++;
                }
            }
        }
        require(counter > 0, "Empty data");
        return unsettledInvoices;
    }

    /**
     * @dev Pay for an unsettled invoice
     * @param index Index of invoice
     * @param beneficiary Beneficiary of invoice
     */
    function payInvoice(uint256 index, address payable beneficiary) public payable notSettledGuard(beneficiary, index, false) {
        require(msg.value >= invoices[beneficiary][index].total, "Insufficient funds");
        invoices[beneficiary][index].settled = true;
        beneficiary.transfer(invoices[beneficiary][index].total);
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
     * @param price Selling price of invoice
     */
    function sellInvoice(uint256 index, uint256 price) public notOverdueGuard(msg.sender, index, false) notSettledGuard(msg.sender, index, false) {
        invoices[msg.sender][index].resellPrice = price;
        Offer memory offer;
        offer.index = invoices[msg.sender].length;
        offer.invoice = invoices[msg.sender][index];
        offer.seller = payable(msg.sender);
        offers.push(offer);
        delete invoices[msg.sender][index];
    }

    /**
     * @dev Sell an invoice
     * @param index Index of Offer
     */
    function buyInvoice(uint256 index)
        public
        payable
        notOverdueGuard(msg.sender, index, true)
        notSettledGuard(msg.sender, index, true)
    {
        Offer memory offer = offers[index];
        require(msg.value >= offer.invoice.resellPrice, "Insufficient funds");
        offer.seller.transfer(offer.invoice.resellPrice * (1/(100-commision)));
        boss.transfer(offer.invoice.resellPrice * (1/(commision)));
        createInvoiceForSender(
            offer.invoice.dueDate,
            offer.invoice.payer,
            offer.invoice.total,
            offer.invoice.total
        );
        delete offers[index];
    }
}

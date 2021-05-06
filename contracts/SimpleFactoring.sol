// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title SimpleFactoring
 * @dev Implements simple factoring
 */
contract SimpleFactoring {
    address payable private boss; // Owner of contract
    uint8 public commission = 2; // 2% commission on invoice sales;

    struct Invoice {
        uint256 index; // Index of Invoice = position in array
        uint256 dueDate; // Deadline of payment
        address payer; // Customer
        bool settled; // If true, the invoice has been paid
        uint256 total; // Amount to be paid in Wei
        uint256 resellPrice; // Invoice price in case of a sale
    }

    mapping(address => Invoice[]) private invoices;
    uint256 public userCount = 1;
    uint256 public invoiceCount;
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

    // Modifier to check if an array of invoices exist and are not overdue
    modifier notOverdueArrayGuard(address sender, uint256[] memory indices) {
        for(uint256 i = 0; i < indices.length; i++) {
            require(
                invoices[sender][indices[i]].dueDate != 0 &&
                    invoices[sender][indices[i]].dueDate > block.timestamp,
                "At least one of the invoices does not exist or is overdue"
            );
        }
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

    // Modifier to check if an array of invoices are settled
    modifier notSettledArrayGuard(address sender, uint256[] memory indices) {
        for(uint256 i = 0; i < indices.length; i++) {
            require(
                invoices[sender][indices[i]].dueDate != 0 &&
                    !invoices[sender][indices[i]].settled,
                "At least one of the invoices does not exist or is settled"
            );
        }
        _;
    }
    
    // Modifier to check if invoice is for sale
    modifier notForSaleGuard(address sender, uint256 index) {
        for(uint256 i = 0; i < offers.length; i++) {
            if(offers[i].seller == sender) {
                require(offers[i].invoice.index != index, "Invoice is for sale");
            }
        }
        _;
    }

    // Modifier to check if an array of invoices are for sale
    modifier notForSaleArrayGuard(address sender, uint256[] memory indices) {
        for(uint256 i = 0; i < offers.length; i++) {
            for(uint256 j = 0; j < indices.length; j++) {
                if(offers[i].seller == sender) {
                    require(offers[i].invoice.index != indices[j], "At least one of the invoices is for sale");
                }
            }
        }
        _;
    }

    // Modifier to check if sender is the owner of an offer
    modifier doesOwnOffer(address sender, uint256 index) {
        require(
            offers[index].seller == sender,
            "Offer does not exist or sender is not the owner of it"
        );
        _;
    }

    /**
     * @dev Set contract deployer as boss
     */
    constructor() {
        boss = payable(msg.sender);
    }
    
    // Helper methods
    // *** ALWAYS PRIVATE FUNCTIONS ***
    
     /**
     * @dev Function to check if an Invoice array is empty
     * @param array Invoice[]
     */
    function isInvoiceArrayEmpty(Invoice[] memory array) private pure returns (bool isEmpty_) {
        isEmpty_ = true;
        for(uint256 i = 0; i < array.length; i++) {
            if(array[i].dueDate != 0) {
                isEmpty_ = false;
            }
        }
    }
    
     /**
     * @dev Function to create an invoice object for sender
     * @param dueDate Timestamp of payment deadline
     * @param payer Address of customer
     * @param total Amount of money to be paid for the invoice in Wei
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
        if (isInvoiceArrayEmpty(invoices[msg.sender])) {
            users[userCount] = msg.sender;
            userCount = userCount + 1;
        }
        invoiceCount = invoiceCount + 1;
        invoices[msg.sender].push(invoice);        
    }
    
    /**
     * @dev Function to delete an invoice object for sender
     * @param index Address of customer
     */
    function deleteInvoiceForSender(uint256 index)
        private        
        notSettledGuard(msg.sender, index, false)
        notForSaleGuard(msg.sender, index)
    {        
        delete invoices[msg.sender][index];
        if (isInvoiceArrayEmpty(invoices[msg.sender])) {
            require(userCount >= 1);
            userCount = userCount - 1;
        }
        require(invoiceCount >= 1);
        invoiceCount = invoiceCount - 1;
    }
    
    /**
     * @dev Function to calculate price with commission
     * @param price Price before commission
     * @return Price with commission
     */
    function getPriceWithCommission(uint256 price) private view returns (uint256) {
        return price - (price*commission)/100;
    }

    // Boss methods

    /**
     * @dev Change commission rate
     * @param percentage New commission rate in percentage
     */
    function setCommission(uint8 percentage) public bossGuard {
        require(percentage >= 0 && percentage <= 100);
        commission = percentage;
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
        // require(invoices[msg.sender].length > 0, "No invoices");
        return invoices[msg.sender];
    }

    /**
     * @dev Create an invoice
     * @param dueDate Timestamp of payment deadline
     * @param payer Address of customer
     * @param total Amount of money to be paid for the invoice in Wei
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
            if (invoices[msg.sender][i].dueDate != 0 && invoices[msg.sender][i].dueDate < block.timestamp) {
                counter_++;
            }
        }
    }

    /**
     * @dev Split invoice for sender
     * @param index Index of invoice to be split
     * @param segments Number of invoices to be created from one
     */
    function splitInvoice(uint256 index, uint256 segments)
        public
        notOverdueGuard(msg.sender, index, false)
        notForSaleGuard(msg.sender, index)
        notSettledGuard(msg.sender, index, false)
    {
        require(segments > 1, "Cannot split invoice into less than 2 segments");
        Invoice memory invoice = invoices[msg.sender][index];
        uint256 total = invoice.total / segments;
        for (uint256 i = 0; i < segments; i++) {
            createInvoiceForSender(
                invoice.dueDate,
                invoice.payer,
                total,
                total
            );
        }
        deleteInvoiceForSender(index);
    }

    /**
     * @dev Merge invoices
     * @param indices Array of invoices to be merged
     */
    function mergeInvoices(uint256[] memory indices)
        public
        notOverdueArrayGuard(msg.sender, indices)
        notForSaleArrayGuard(msg.sender, indices)
        notSettledArrayGuard(msg.sender, indices)
    {
        require(indices.length > 0, "Empty input");
        uint256 dueDate = invoices[msg.sender][indices[0]].dueDate;
        address payer = invoices[msg.sender][indices[0]].payer;
        for (uint256 i = 1; i < indices.length; i++) {
            require(invoices[msg.sender][indices[i]].dueDate == dueDate, "Invoices' due dates are not identical");
            require(invoices[msg.sender][indices[i]].payer == payer, "Invoices' payers are not identical");
        }
        uint256 total;
        for (uint256 i = 0; i < indices.length; i++) {
            total += invoices[msg.sender][indices[i]].total;
            deleteInvoiceForSender(indices[i]);
        }
        createInvoiceForSender(dueDate, payer, total, total);
    }
    
    /**
     * @dev Delete an invoice
     * @param index Index of invoice
     */
    function deleteInvoice(uint256 index) public {
        deleteInvoiceForSender(index);
    }

    // Payer methods

    /**
     * @dev Get all unsettled invoices
     * @return unsettledInvoices_ User's unsettled invoices
     */
    function getUnsettledInvoices() public view returns (PayableInvoice[] memory) {
        uint256 arraySize = userCount * invoiceCount;
        if (arraySize > 0) {
            PayableInvoice[] memory unsettledInvoices = new PayableInvoice[](arraySize);
            uint256 counter;
            for (uint256 i = 0; i < userCount; i++) {
                for (uint256 j = 0; j < invoices[users[i]].length; j++) {
                    if (invoices[users[i]][j].payer == msg.sender && !invoices[users[i]][j].settled) {
                        PayableInvoice memory payableInvoice;
                        payableInvoice.invoice = invoices[users[i]][j];
                        payableInvoice.beneficiary = payable(users[i]);
                        unsettledInvoices[counter] = payableInvoice;
                        counter++;
                    }
                }
            }
            if (counter > 0) {
                PayableInvoice[] memory unsettledInvoicesFiltered = new PayableInvoice[](counter);
                for (uint256 i = 0; i < counter; i++) {
                    unsettledInvoicesFiltered[i] = unsettledInvoices[i];
                }
                return unsettledInvoicesFiltered;
            } else {
                return new PayableInvoice[](0);
            }
        } else {
            return new PayableInvoice[](0);
        }
    }

    /**
     * @dev Pay for an unsettled invoice
     * @param index Index of invoice
     * @param beneficiary Beneficiary of invoice
     */
    function payInvoice(uint256 index, address payable beneficiary)
        public
        payable
        notSettledGuard(beneficiary, index, false)
    {
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
        require(offers.length > 0, "No offers");
        return offers;
    }

    /**
     * @dev Sell an invoice
     * @param index Position of invoice within seller's invoices
     * @param price Selling price of invoice
     */
    function sellInvoice(uint256 index, uint256 price)
        public
        notOverdueGuard(msg.sender, index, false)
        notSettledGuard(msg.sender, index, false)
    {
        invoices[msg.sender][index].resellPrice = price;
        Offer memory offer;
        offer.index = invoices[msg.sender].length;
        offer.invoice = invoices[msg.sender][index];
        offer.seller = payable(msg.sender);
        offers.push(offer);
    }

    /**
     * @dev Delete an invoice offer
     * @param index Position of invoice within seller's invoices
     */
    function deleteInvoiceOffer(uint256 index) public doesOwnOffer(msg.sender, index) {
        delete offers[index];
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
        offer.seller.transfer(getPriceWithCommission(offer.invoice.resellPrice));
        deleteInvoiceForSender(offer.invoice.index);
        delete offers[index];
        createInvoiceForSender(
            offer.invoice.dueDate,
            offer.invoice.payer,
            offer.invoice.total,
            offer.invoice.total
        );
    }
}

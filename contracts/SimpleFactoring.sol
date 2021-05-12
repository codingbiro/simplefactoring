// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title SimpleFactoring
 * @dev Implements simple factoring
 */
contract SimpleFactoring {
    address payable private boss; // Owner of contract
    uint8 public commission = 2; // 2% commission on invoice sales;
    bool private checkSignature = false;

    struct Invoice {
        uint256 index; // Index of Invoice = position in array
        uint256 dueDate; // Deadline of payment
        address payer; // Customer
        bool settled; // If true, the invoice has been paid
        uint256 total; // Amount to be paid in Wei
        uint256 resellPrice; // Invoice price in case of a sale
        bool verified; // If true, the payer has verified the invoice
    }

    mapping(address => Invoice[]) private invoices;
    uint256 private userCount;
    uint256 private invoiceCount;
    mapping (uint256 => address) private users;
    mapping(address => DueDateExtensionRequest[]) private dueDateExtensionRequests;
    mapping(address => Invoice[]) private signatureRequests;

    struct DueDateExtensionRequest{
        uint256 index; // index of the request = position in the due date extension array
        Invoice invoice; // invoice connected to the extension request
        uint256 newDueDate; // the requested new due date of the invoice
        uint256 fee; // the fee in return of the due date extension
    }

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
                    !offers[index].invoice.settled,
                "Offer does not exist or is settled"
            )
            : require(
                invoices[sender][index].dueDate != 0 &&
                    !invoices[sender][index].settled,
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

    // Modifier to check if sender is the payer of an invoice
    modifier debtorGuard(address sender, address beneficiary, uint256 index) {
        require(
            dueDateExtensionRequests[beneficiary][index].invoice.payer == sender,
            "Offer does not exist or the person who wants to create the request is not the debtor."
        );
        _;
    }

    // Modifier to check if the invoice is already verified by payer
    modifier isVerifiedGuard(address beneficiary, uint256 index) {
        require(
            invoices[beneficiary][index].verified == true,
            "The invoice has not been verified by the payer yet."
        );
        _;
    }

    // Modifier to check if an array of invoices are settled
    modifier isVerifiedArrayGuard(address beneficiary, uint256[] memory indices) {
        for(uint256 i = 0; i < indices.length; i++) {
            require(
                invoices[beneficiary][indices[i]].verified == true,
                "At least one of the invoices not verified"
            );
        }
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
        
        if(checkSignature){
            invoice.verified = false;
        }
        else{
            invoice.verified = true;
        }
        if (isInvoiceArrayEmpty(invoices[msg.sender])) {
            users[userCount] = msg.sender;
            userCount = userCount + 1;
        }
        invoiceCount = invoiceCount + 1;
        invoices[msg.sender].push(invoice); 
        signatureRequests[payer].push(invoice);
    }
    
    /**
     * @dev Function to delete an invoice object for sender
     * @param index Address of customer
     */
    function deleteInvoiceForUser(uint256 index, address sender)
        private
        notSettledGuard(sender, index, false)
        notForSaleGuard(sender, index)
    {
        delete invoices[sender][index];
        if (isInvoiceArrayEmpty(invoices[sender])) {
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
        uint256 total,
        uint _nonce,
        bytes memory _signature
    ) public {  
        if(checkSignature){
            require(verify(msg.sender, payer, total, dueDate, total, _nonce, _signature) == true, "Could not verify signature of the message.");
        }
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
        isVerifiedGuard(msg.sender, index)
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
        deleteInvoiceForUser(index, msg.sender);
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
        isVerifiedArrayGuard(msg.sender, indices)
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
            deleteInvoiceForUser(indices[i], msg.sender);
        }
        createInvoiceForSender(dueDate, payer, total, total);
    }
    
    /**
     * @dev Delete an invoice
     * @param index Index of invoice
     */
    function deleteInvoice(uint256 index) public {
        deleteInvoiceForUser(index, msg.sender);
    }

    /**
     * @dev Returns the verifiable invoices of the msg.sender
     */
    function getMyInvoiceSignatureRequests() public view returns (Invoice[] memory) {
        return signatureRequests[msg.sender];
    }

    /**
     * @dev Verifies a signature of the payer on the given invoice
     */
    function verifyInvoicePayerSignature(uint256 index, bytes memory signature, uint _nonce)  public returns (bool){
        bool verified = verify(msg.sender,
            msg.sender,
            signatureRequests[msg.sender][index].total,
            signatureRequests[msg.sender][index].dueDate,
            signatureRequests[msg.sender][index].resellPrice,
            _nonce,
            signature);
        if(verified){
            signatureRequests[msg.sender][index].verified = true;
            delete signatureRequests[msg.sender][index];
        }
        return verified;
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
        isVerifiedGuard(beneficiary, index)
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
        isVerifiedGuard(msg.sender, index)
    {
        invoices[msg.sender][index].resellPrice = price;
        Offer memory offer;
        offer.index = offers.length;
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
        require(index < offers.length, "Invalid index");
        Offer memory offer = offers[index];
        require(msg.value >= offer.invoice.resellPrice, "Insufficient funds");
        offer.seller.transfer(getPriceWithCommission(offer.invoice.resellPrice));
        delete offers[index];
        deleteInvoiceForUser(offer.invoice.index, offer.seller);
        createInvoiceForSender(
            offer.invoice.dueDate,
            offer.invoice.payer,
            offer.invoice.total,
            offer.invoice.total
        );
    }


    /**
     * @dev Request due date extension of the given invoice
     * @param index Index of invoice in the invoices arrays
     * @param beneficiary Beneficiary of invoice
     */
    function createDueDateExtensionRequest(
        uint256 index,
        address beneficiary,
        uint256 newDueDate,
        uint256 feeInReturn
    ) public notOverdueGuard(beneficiary, index, false) debtorGuard(msg.sender, beneficiary, index) isVerifiedGuard(beneficiary, index) {
        DueDateExtensionRequest memory request;
        request.invoice = invoices[beneficiary][index];
        request.newDueDate = newDueDate;
        request.fee = feeInReturn;
        request.index = dueDateExtensionRequests[beneficiary].length;
        dueDateExtensionRequests[beneficiary].push(request);
    }

    /**
     * @dev Returns due date extension request connected to the owned invoices of the user
     */
    function getMyDueDateExtensionRequests() public view returns (DueDateExtensionRequest[] memory) {
        return dueDateExtensionRequests[msg.sender];
    }

    /**
     * @dev Answers a request for due date extension
     * @param index Index of request in the dueDateExtensionRequests arrays
     * @param accept the answer for the request (true = accept, false = reject)
     */
    function answerDueDateExtensionRequest(uint256 index, bool accept)
        public
        notOverdueGuard(msg.sender, dueDateExtensionRequests[msg.sender][index].invoice.index, false)
    {
        if (accept) {
            invoices[msg.sender][dueDateExtensionRequests[msg.sender][index].invoice.index].dueDate =
                dueDateExtensionRequests[msg.sender][index].newDueDate;
            invoices[msg.sender][dueDateExtensionRequests[msg.sender][index].invoice.index].total = 
                invoices[msg.sender][dueDateExtensionRequests[msg.sender][index].invoice.index].total + dueDateExtensionRequests[msg.sender][index].fee;
            invoices[msg.sender][dueDateExtensionRequests[msg.sender][index].invoice.index].resellPrice = 
                invoices[msg.sender][dueDateExtensionRequests[msg.sender][index].invoice.index].resellPrice + dueDateExtensionRequests[msg.sender][index].fee;
        }
        delete dueDateExtensionRequests[msg.sender][index];
    }    



    /**
     * @dev Returns message hash of the given message details
     * @param _from payer of the invoice
     * @param _amount total value of the invoice
     * @param _duedate initial due date of the invoice
     * @param _resellPrice resell price of the invoice
     * @param _nonce nonce value of the given message
     */
    function getMessageHash(
        address _from, uint _amount, uint256 _duedate, uint _resellPrice, uint _nonce
    )
        public pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(_from, _amount, _duedate, _resellPrice, _nonce));
    }

     /**
     * @dev Returns the signed version of the given message hash
     * @param _messageHash signable message hash
     */
    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    /**
     * @dev Verifies a signature, returns true if verified
     * @param _from payer of the invoice
     * @param _amount total value of the invoice
     * @param _duedate initial due date of the invoice
     * @param _resellPrice resell price of the invoice
     * @param _nonce nonce value of the given message
     * @param signature the given signature to verify
     */
    function verify(
        address _signer,
        address _from, uint _amount, uint256 _duedate, uint _resellPrice, uint _nonce,
        bytes memory signature
    )
        public pure returns (bool)
    {
        bytes32 messageHash = getMessageHash(_from, _amount, _duedate, _resellPrice, _nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    /**
     * @dev recovers the address of the signer from the signed message hash
     * @param _ethSignedMessageHash the signed message hash
     * @param _signature signature of the signer who signed the message
     */
    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public pure returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    /**
     * @dev splits the given signature at its r,s, and v parts
     * @param r param r
     * @param s param s
     * @param v param v
     */
    function splitSignature(bytes memory sig)
        public pure returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature
            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature
            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
    
}

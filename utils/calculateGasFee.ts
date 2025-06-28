import {
  ethers,
  JsonRpcProvider,
  AbiCoder,
  ZeroAddress,
  formatEther,
  parseEther,
} from "ethers";
import { Client } from "@chainlink/contract-ccip/contracts/libraries/Client";
import { SpokeContract__factory } from "../typechain-types";

// Enum matching the contract's CCIPMessageType
export enum CCIPMessageType {
  DEPOSIT = 0,
  DEPOSIT_COLLATERAL = 1,
  WITHDRAW = 2,
  WITHDRAW_COLLATERAL = 3,
  BORROW = 4,
  CREATE_REQUEST = 5,
  SERVICE_REQUEST = 6,
  CREATE_LISTING = 7,
  BORROW_FROM_LISTING = 8,
  REPAY = 9,
  REPAY_LOAN = 10,
  LIQUIDATE = 11,
}

interface GasFeeParams {
  spokeContractAddress: string;
  provider: JsonRpcProvider;
  messageType: CCIPMessageType;
  params: any; // This will be typed based on the message type
}

export async function calculateGasFee({
  spokeContractAddress,
  provider,
  messageType,
  params,
}: GasFeeParams): Promise<bigint> {
  const spokeContract = SpokeContract__factory.connect(
    spokeContractAddress,
    provider
  );

  // Create the appropriate message based on the message type
  const message = await createMessage(messageType, params);

  // Get the fee using the contract's getFees function
  const fee = await spokeContract.getFees(message);
  return fee;
}

async function createMessage(
  messageType: CCIPMessageType,
  params: any
): Promise<Client.EVM2AnyMessage> {
  const baseMessage: Client.EVM2AnyMessage = {
    receiver: ethers.ZeroAddress, // This will be set by the contract
    data: ethers.ZeroAddress, // This will be set based on the message type
    tokenAmounts: [], // This will be set based on the message type
    extraArgs: Client._argsToBytes(
      Client.GenericExtraArgsV2({
        gasLimit: getGasLimitForMessageType(messageType),
        allowOutOfOrderExecution: true,
      })
    ),
    feeToken: ethers.ZeroAddress,
  };

  switch (messageType) {
    case CCIPMessageType.DEPOSIT:
      return createDepositMessage(params, baseMessage);
    case CCIPMessageType.WITHDRAW:
      return createWithdrawMessage(params, baseMessage);
    case CCIPMessageType.BORROW:
      return createBorrowMessage(params, baseMessage);
    case CCIPMessageType.REPAY:
      return createRepayMessage(params, baseMessage);
    case CCIPMessageType.CREATE_REQUEST:
      return createRequestMessage(params, baseMessage);
    case CCIPMessageType.SERVICE_REQUEST:
      return createServiceRequestMessage(params, baseMessage);
    case CCIPMessageType.CREATE_LISTING:
      return createListingMessage(params, baseMessage);
    case CCIPMessageType.BORROW_FROM_LISTING:
      return createBorrowFromListingMessage(params, baseMessage);
    case CCIPMessageType.REPAY_LOAN:
      return createRepayLoanMessage(params, baseMessage);
    case CCIPMessageType.DEPOSIT_COLLATERAL:
      return createDepositCollateralMessage(params, baseMessage);
    case CCIPMessageType.WITHDRAW_COLLATERAL:
      return createWithdrawCollateralMessage(params, baseMessage);
    default:
      throw new Error(`Unsupported message type: ${messageType}`);
  }
}

function getGasLimitForMessageType(messageType: CCIPMessageType): number {
  switch (messageType) {
    case CCIPMessageType.DEPOSIT:
      return 400_000;
    case CCIPMessageType.WITHDRAW:
      return 300_000;
    case CCIPMessageType.BORROW:
      return 600_000;
    case CCIPMessageType.REPAY:
      return 600_000;
    case CCIPMessageType.CREATE_REQUEST:
      return 600_000;
    case CCIPMessageType.SERVICE_REQUEST:
      return 500_000;
    case CCIPMessageType.CREATE_LISTING:
      return 300_000;
    case CCIPMessageType.BORROW_FROM_LISTING:
      return 1_000_000;
    case CCIPMessageType.REPAY_LOAN:
      return 300_000;
    case CCIPMessageType.DEPOSIT_COLLATERAL:
      return 200_000;
    case CCIPMessageType.WITHDRAW_COLLATERAL:
      return 400_000;
    default:
      return 300_000; // Default gas limit
  }
}

// Helper functions to create specific message types
function createDepositMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { tokenAddress, amountToDeposit, sender } = params;
  const isNative = tokenAddress === ZeroAddress;

  const tokensToSendDetails: Client.EVMTokenAmount[] = [
    {
      token: isNative ? ZeroAddress : tokenAddress, // WETH address will be set by contract
      amount: BigInt(amountToDeposit),
    },
  ];

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.DEPOSIT,
      abiCoder.encode(
        ["bool", "uint256", "address"],
        [isNative, amountToDeposit, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: tokensToSendDetails,
  };
}

function createWithdrawMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { tokenAddress, amountToWithdraw, sender } = params;

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.WITHDRAW,
      abiCoder.encode(
        ["address", "uint256", "address"],
        [tokenAddress, amountToWithdraw, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: [], // No tokens sent in withdraw message
  };
}

function createBorrowMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { tokenAddress, amountToBorrow, sender } = params;

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.BORROW,
      abiCoder.encode(
        ["address", "uint256", "address"],
        [tokenAddress, amountToBorrow, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: [], // No tokens sent in borrow message
  };
}

function createRepayMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { tokenAddress, amountToRepay, sender } = params;
  const isNative = tokenAddress === ZeroAddress;

  const tokensToSendDetails: Client.EVMTokenAmount[] = [
    {
      token: isNative ? ZeroAddress : tokenAddress,
      amount: BigInt(amountToRepay),
    },
  ];

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.REPAY,
      abiCoder.encode(
        ["bool", "address", "address", "uint256"],
        [isNative, tokenAddress, sender, amountToRepay]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: tokensToSendDetails,
  };
}

function createRequestMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { amount, interest, returnDate, loanCurrency, sender } = params;

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.CREATE_REQUEST,
      abiCoder.encode(
        ["uint256", "uint16", "uint256", "address", "address"],
        [amount, interest, returnDate, loanCurrency, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: [], // No tokens sent in create request message
  };
}

function createServiceRequestMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { requestId, tokenAddress, amount, sender } = params;
  const isNative = tokenAddress === ZeroAddress;

  const tokensToSendDetails: Client.EVMTokenAmount[] = [
    {
      token: isNative ? ZeroAddress : tokenAddress,
      amount: BigInt(amount),
    },
  ];

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.SERVICE_REQUEST,
      abiCoder.encode(
        ["uint96", "bool", "address"],
        [requestId, isNative, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: tokensToSendDetails,
  };
}

function createListingMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const {
    sender,
    loanCurrency,
    amount,
    minAmount,
    maxAmount,
    interest,
    returnDate,
    whitelist,
  } = params;
  const isNative = loanCurrency === ZeroAddress;

  const tokensToSendDetails: Client.EVMTokenAmount[] = [
    {
      token: isNative ? ZeroAddress : loanCurrency,
      amount: BigInt(amount),
    },
  ];

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.CREATE_LISTING,
      abiCoder.encode(
        [
          "address",
          "address",
          "uint256",
          "uint256",
          "uint256",
          "uint16",
          "uint256",
          "address[]",
        ],
        [
          sender,
          loanCurrency,
          amount,
          minAmount,
          maxAmount,
          interest,
          returnDate,
          whitelist,
        ]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: tokensToSendDetails,
  };
}

function createBorrowFromListingMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { sender, listingId, amount } = params;

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.BORROW_FROM_LISTING,
      abiCoder.encode(
        ["address", "uint96", "uint256"],
        [sender, listingId, amount]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: [], // No tokens sent in borrow from listing message
  };
}

function createRepayLoanMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { requestId, amount, token, sender } = params;
  const isNative = token === ZeroAddress;

  const tokensToSendDetails: Client.EVMTokenAmount[] = [
    {
      token: isNative ? ZeroAddress : token,
      amount: BigInt(amount),
    },
  ];

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.REPAY_LOAN,
      abiCoder.encode(
        ["uint96", "uint256", "address"],
        [requestId, amount, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: tokensToSendDetails,
  };
}

function createDepositCollateralMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { tokenCollateralAddress, amountOfCollateral, sender } = params;
  const isNative = tokenCollateralAddress === ZeroAddress;

  const tokensToSendDetails: Client.EVMTokenAmount[] = [
    {
      token: isNative ? ZeroAddress : tokenCollateralAddress,
      amount: BigInt(amountOfCollateral),
    },
  ];

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.DEPOSIT_COLLATERAL,
      abiCoder.encode(["bool", "address"], [isNative, sender]),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: tokensToSendDetails,
  };
}

function createWithdrawCollateralMessage(
  params: any,
  baseMessage: Client.EVM2AnyMessage
): Client.EVM2AnyMessage {
  const { tokenCollateralAddress, amountOfCollateral, sender } = params;

  const abiCoder = new AbiCoder();
  const messageData = abiCoder.encode(
    ["uint8", "bytes"],
    [
      CCIPMessageType.WITHDRAW_COLLATERAL,
      abiCoder.encode(
        ["address", "uint256", "address"],
        [tokenCollateralAddress, amountOfCollateral, sender]
      ),
    ]
  );

  return {
    ...baseMessage,
    data: messageData,
    tokenAmounts: [], // No tokens sent in withdraw collateral message
  };
}

// Example usage:
/*
const fee = await calculateGasFee({
    spokeContractAddress: "0x...",
    provider: new JsonRpcProvider("RPC_URL"),
    messageType: CCIPMessageType.DEPOSIT,
    params: {
        tokenAddress: "0x...",
        amountToDeposit: parseEther("1.0"),
        sender: "0x..."
    }
});
*/

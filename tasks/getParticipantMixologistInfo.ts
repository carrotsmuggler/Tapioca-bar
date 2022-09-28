import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import {
    getMixologistContract,
    getMixologistHelperContract,
    getYieldBoxContract,
} from './utils';

//Execution example:
//      npx hardhat getParticipantMixologistInfo --mixologist "<address>" --participant "<address>"
export const getDetails = async (
    taskArgs: any,
    hre: HardhatRuntimeEnvironment,
) => {
    const userAddress = taskArgs['participant'];
    const { mixologistContract, mixologistAddress } =
        await getMixologistContract(taskArgs, hre);

    const { mixologistHelperContract } = await getMixologistHelperContract(
        taskArgs,
        hre,
    );
    const { yieldBoxContract } = await getYieldBoxContract(taskArgs, hre);

    const assetId = await mixologistContract.assetId();
    const collateralId = await mixologistContract.collateralId();

    const borrowAmount = await mixologistContract.userBorrowPart(userAddress);
    const borrowShare = await yieldBoxContract.toShare(
        assetId,
        borrowAmount,
        false,
    );

    const collateralShare = await mixologistContract.userCollateralShare(
        userAddress,
    );
    const collateralAmount = await yieldBoxContract.toAmount(
        collateralId,
        collateralShare,
        false,
    );
    const exchangeRate = await mixologistContract.exchangeRate();
    const amountToSolvency =
        await mixologistContract.computeAssetAmountToSolvency(
            userAddress,
            exchangeRate,
        );

    const collateralUsedShares =
        await mixologistHelperContract.getCollateralSharesForBorrowPart(
            mixologistAddress,
            borrowAmount,
        );
    const collateralUsedAmount = await yieldBoxContract.toAmount(
        collateralId,
        collateralUsedShares,
        false,
    );

    return {
        borrowAmount: borrowAmount,
        borrowShare: borrowShare,
        collateralAmount: collateralAmount,
        collateralShare: collateralShare,
        exchangeRate: exchangeRate,
        amountToSolvency: amountToSolvency,
        collateralSharesUsed: collateralUsedShares,
        collateralAmountUsed: collateralUsedAmount,
    };
};

export const getParticipantMixologistInfo__task = async (
    args: any,
    hre: HardhatRuntimeEnvironment,
) => {
    console.log(await getDetails(args, hre));
};

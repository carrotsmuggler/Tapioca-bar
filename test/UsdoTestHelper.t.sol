// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// Lz
import {TestHelper} from "./LZSetup/TestHelper.sol";

// External
import {IERC20} from "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

// Tapioca
import {UsdoInitStruct, UsdoModulesInitStruct} from "tapioca-periph/interfaces/oft/IUsdo.sol";
import {SimpleLeverageExecutor} from "contracts/markets/leverage/SimpleLeverageExecutor.sol";
import {ILeverageExecutor} from "tapioca-periph/interfaces/bar/ILeverageExecutor.sol";
import {ERC20WithoutStrategy} from "yieldbox/strategies/ERC20WithoutStrategy.sol";
import {SGLLiquidation} from "contracts/markets/singularity/SGLLiquidation.sol";
import {SGLCollateral} from "contracts/markets/singularity/SGLCollateral.sol";
import {SGLLeverage} from "contracts/markets/singularity/SGLLeverage.sol";
import {Singularity} from "contracts/markets/singularity/Singularity.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {ISwapper} from "tapioca-periph/interfaces/periph/ISwapper.sol";
import {SGLBorrow} from "contracts/markets/singularity/SGLBorrow.sol";
import {IWrappedNative} from "yieldbox/interfaces/IWrappedNative.sol";
import {IOracle} from "tapioca-periph/oracle/interfaces/IOracle.sol";
import {IPenrose} from "tapioca-periph/interfaces/bar/IPenrose.sol";
import {YieldBoxURIBuilder} from "yieldbox/YieldBoxURIBuilder.sol";
import {TokenType} from "yieldbox/enums/YieldBoxTokenType.sol";
import {IYieldBox} from "yieldbox/interfaces/IYieldBox.sol";
import {IStrategy} from "yieldbox/interfaces/IStrategy.sol";
import {Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {MagnetarMock} from "./MagnetarMock.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";
import {Penrose} from "contracts/Penrose.sol";
import {SwapperMock} from "./SwapperMock.sol";
import {OracleMock} from "./OracleMock.sol";
import {TestUtils} from "./TestUtils.t.sol";

struct TestPenroseData {
    address yb;
    address cluster;
    address tap;
    address token;
    address owner;
}

struct TestSingularityData {
    address penrose;
    IERC20 asset;
    uint256 assetId;
    IERC20 collateral;
    uint256 collateralId;
    IOracle oracle;
    ILeverageExecutor leverageExecutor;
}

contract UsdoTestHelper is TestHelper, TestUtils {
    function createYieldBoxEmptyStrategy(address _yieldBox, address _erc20) public returns (ERC20WithoutStrategy) {
        return new ERC20WithoutStrategy(IYieldBox(_yieldBox), IERC20(_erc20));
    }

    function registerYieldBoxAsset(address _yieldBox, address _token, address _strategy) public returns (uint256) {
        return YieldBox(_yieldBox).registerAsset(TokenType.ERC20, _token, IStrategy(_strategy), 0);
    }

    function createMagnetar(address cluster) public returns (MagnetarMock) {
        return new MagnetarMock(cluster);
    }

    function createYieldBox() public returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();

        return new YieldBox(IWrappedNative(address(0)), uriBuilder);
    }

    function createCluster(uint32 hostEid, address owner) public returns (Cluster) {
        return new Cluster(hostEid, owner);
    }

    function createSwapper(YieldBox _yb) public returns (SwapperMock) {
        return new SwapperMock(_yb);
    }

    function createOracle() public returns (OracleMock) {
        return new OracleMock("Oracle Test", "ORCT", 1 ether);
    }

    function createLeverageExecutor(address _yb, address _swapper, address _cluster)
        public
        returns (SimpleLeverageExecutor)
    {
        return new SimpleLeverageExecutor(IYieldBox(_yb), ISwapper(_swapper), ICluster(_cluster));
    }

    function createPenrose(TestPenroseData memory _data) public returns (Penrose pen, Singularity mediumRiskMC) {
        pen = new Penrose(
            IYieldBox(_data.yb), ICluster(_data.cluster), IERC20(_data.tap), IERC20(_data.token), _data.owner
        );
        mediumRiskMC = new Singularity();

        pen.registerSingularityMasterContract(address(mediumRiskMC), IPenrose.ContractType.mediumRisk);
    }

    function createSingularity(Penrose _penrose, TestSingularityData memory _sgl, address _mc)
        public
        returns (Singularity)
    {
        Singularity sgl = new Singularity();
        (bytes memory _modulesData, bytes memory _tokensData, bytes memory _data) =
            _getSingularityInitData(_sgl, address(_penrose));
        {
            sgl.init(_modulesData, _tokensData, _data);
        }

        {
            _penrose.addSingularity(_mc, address(sgl));
        }
        return sgl;
    }

    function _getSingularityInitData(TestSingularityData memory _sgl, address _penrose)
        private
        returns (bytes memory modulesData, bytes memory tokensData, bytes memory data)
    {
        SGLLiquidation sglLiq = new SGLLiquidation();
        SGLBorrow sglBorrow = new SGLBorrow();
        SGLCollateral sglCollateral = new SGLCollateral();
        SGLLeverage sglLev = new SGLLeverage();

        modulesData = abi.encode(address(sglLiq), address(sglBorrow), address(sglCollateral), address(sglLev));

        tokensData = abi.encode(_sgl.asset, _sgl.assetId, _sgl.collateral, _sgl.collateralId);

        data = abi.encode(_penrose, _sgl.oracle, 0, 75000, 80000, _sgl.leverageExecutor);
    }
}

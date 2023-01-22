pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT


contract CourseContract {

    bool public courseStatus; //Is determined by the teacher. Can be used with signup status to give 4 states: pending, open, in progress and closed.
    bool public signupStatus; //Once payment is set by teacher, enrollment can begin
    uint public payment; //Amount requested by the teacher, also the amount that needs to be sponsored to start the course
    uint public studentStake; //Amount student needs to stake to enroll in the course, possible platform rewards for staking in future versions?
    uint public sponsorshipTotal; //Total Sponsorship amount
    address public peaceAntzCouncil = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148; //address that will be sent stake of students who dropout
//0x6bE3d955Cb6cF9A52Bc3c92F453309931012D386


//Events for pretty much each function
    event GrantRole(bytes32 indexed role, address indexed account);
    event RevokeRole(bytes32 indexed role, address indexed account);
    event DropOut(bytes32 indexed role, address indexed account);
    event CourseStatus(bool indexed courseStatus);
    event SignupStatus(bool indexed signupStatus);
    event StudentEnrolled(address indexed account);
    event Sponsored(uint indexed sponsorDeposit, address indexed account);
    event CourseCompleted(bool indexed pass, address indexed account);

    //role => account = bool to keep track of roles of addresses
    mapping(bytes32 => mapping(address => bool)) public roles;

    //Need to track each address that deposits as a sponsor or student
    mapping (address => uint) public studentDeposit;
    mapping (address => uint) public sponsorDeposit;
    //track pass/fail for each student
    mapping (address => bool) public courseCompleted;

//Different Roles stored as bytes32 NOTE: ADMIN will be set to the multisig address.
    //0xdf8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42
    bytes32 private constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    //0x534b5b9fe29299d99ea2855da6940643d68ed225db268dc8d86c1f38df5de794
    bytes32 private constant TEACHER = keccak256(abi.encodePacked("TEACHER"));
    //0xc951d7098b66ba0b8b77265b6e9cf0e187d73125a42bcd0061b09a68be421810
    bytes32 private constant STUDENT = keccak256(abi.encodePacked("STUDENT"));
    //0x5f0a5f78118b6e0b700e0357ae3909aaafe8fa706a075935688657cf4135f9a9
    bytes32 private constant SPONSOR = keccak256(abi.encodePacked("SPONSOR"));

//Access control modifier
    modifier onlyRole(bytes32 _role){
        require(roles[_role][msg.sender], "not authorized");
        _;
    }
//Sets the contract creator as the TEACHER and the multisig wallet as the ADMIN
    constructor() payable{
        _grantRole(ADMIN, msg.sender);
        _grantRole(TEACHER, msg.sender);
    }

//Admin Functions
    function _grantRole(bytes32 _role, address _account) internal{
        roles[_role][_account] = true;
        emit GrantRole(_role, _account);
    }

    function grantRole(bytes32 _role, address _account) external onlyRole(ADMIN){
        _grantRole(_role,_account);
    }

    function revokeRole(bytes32 _role, address _account) external onlyRole(ADMIN){
        roles[_role][_account] = false;
        emit RevokeRole(_role, _account);
    }

//Teacher Functions
    //"Start Course" Button, locks in enrollments and sponsorship payments
    function updateCourseStatus() external onlyRole(TEACHER){
        require(payment == sponsorshipTotal, "Course is has not been fully sponsored yet :(");
        courseStatus=true;
        signupStatus=false;
        emit CourseStatus(true);
        emit SignupStatus(false);
    }
    //Teach sets how much they want to be paid, allows enrollment to start, cannot be changed.
    function setAmount(uint _payment) external onlyRole(TEACHER){
        require(signupStatus==false, "You cannot change change payment after it has been set, please create another course.");
        require(courseStatus==false, "You cannot change the payment.");
        payment = _payment;
        unchecked {
            studentStake= _payment/15;
        }
        signupStatus=true;
        emit SignupStatus(true);
    }
    
    function passStudent(address _account) external onlyRole(TEACHER){
        require(roles[STUDENT][_account],"Not a student!");
        courseCompleted[_account]=true;
        emit CourseCompleted(true,_account);
    }
    function bootStudent(address _account) external onlyRole(TEACHER){
        (bool success, ) = peaceAntzCouncil.call{value: studentStake}("");
        require(success, "Failed to boot >:(");
        roles[STUDENT][_account] = false;
        emit DropOut(STUDENT, _account);
    }
    function claimPayment() external onlyRole(TEACHER){
        //require(what is needed here? hmm);
        (bool success, ) = msg.sender.call{value: payment}("");
        require(success, "Failed to boot >:(");
    }


//Student Functions
    function enroll()external payable{
        require(courseStatus == false, "Course has already started :("); 
        require(!roles[STUDENT][msg.sender],"You are enrolled already!");
        require(msg.value == studentStake, "Please Stake the Correct Amount");
        require(signupStatus == true, "Enrollment Closed");
        studentStake = msg.value;
        roles[STUDENT][msg.sender] = true;
        studentDeposit[msg.sender] = studentStake;
        emit StudentEnrolled(msg.sender);
    }

    function withdraw () external payable {
        require(roles[STUDENT][msg.sender],"You are not enrolled!");
        require(address(this).balance >0, "No balance available");
        require(courseStatus == false, "You have to dropout because the course has started.");
        require(msg.value == 0,"Leave value empty.");

        (bool success, ) = msg.sender.call{value: studentStake}("");
        require(success, "Failed to withdraw :(");
        studentDeposit[msg.sender] = 0;
        roles[STUDENT][msg.sender] = false;
        emit RevokeRole(STUDENT, msg.sender);

    }

    function dropOut() external payable onlyRole(STUDENT){
        require(courseStatus == true, "Course has not started yet, feel free to simply withdraw :)");
        require(courseCompleted[msg.sender] == false, "You have completed the course already!");
        (bool success, ) = peaceAntzCouncil.call{value: studentStake}("");
        require(success, "Failed to drop course :(");
        roles[STUDENT][msg.sender] = false;
        emit DropOut(STUDENT, msg.sender);
    }


//Sponsor Functions
    //Allows sponsor to send ETH to contract and sill remember the amount of each sponsor and total amount.
    function sponsor() external payable {
        require(courseStatus == false, "Course has already begun.");
        require(payment>sponsorshipTotal,"This course is fully sponsored :)");
        require(msg.value >0, "Please input amount you wish to sponsor");
        require(msg.value<=(payment-sponsorshipTotal), "Please input the Sponsorship amount needed or less");
        roles[SPONSOR][msg.sender] = true;
        uint currentDeposit = sponsorDeposit[msg.sender] + msg.value;
        uint _sponsorshipTotal = sponsorshipTotal + msg.value;
        assert(_sponsorshipTotal >= sponsorshipTotal);
        sponsorshipTotal = _sponsorshipTotal;
        sponsorDeposit[msg.sender] = currentDeposit;
        emit Sponsored(currentDeposit, msg.sender);
    }
    //Allows user to withdraw whatever they sponsored before the course begins
    function unsponsor(address payable _to, uint _amount) external payable onlyRole(SPONSOR){
        require(courseStatus == false, "Course has already begun.");
        require(_amount>0,"Please input an amount to unsponsor");
        require(_amount<=sponsorDeposit[_to], "That is more than you have sponsored");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to withdraw :(");

        uint currentDeposit = sponsorDeposit[_to] - _amount;
        assert(currentDeposit <= sponsorDeposit[_to]);
        uint _sponsorshipTotal = sponsorshipTotal - _amount;
        assert(_sponsorshipTotal <= sponsorshipTotal);
        sponsorshipTotal = _sponsorshipTotal;
        sponsorDeposit[_to]=currentDeposit;
        if (sponsorDeposit[_to] == 0){
        roles[STUDENT][_to] = false;
        emit RevokeRole(SPONSOR, _to);
        }
    }
}

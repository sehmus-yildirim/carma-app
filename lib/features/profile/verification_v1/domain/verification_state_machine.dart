enum VerificationFlowState {
  notStarted,
  capturingIdentity,
  processingIdentity,
  identityRetryRequired,
  identityDataChecked,
  capturingVehicle,
  processingVehicle,
  vehicleRetryRequired,
  awaitingDeclaration,
  declarationSigning,
  verified,
  expired,
  reverificationRequired,
  failed,
}

class VerificationStateMachine {
  VerificationStateMachine({
    VerificationFlowState initialState = VerificationFlowState.notStarted,
  }) : _state = initialState;

  VerificationFlowState _state;

  VerificationFlowState get state => _state;

  bool canTransitionTo(VerificationFlowState next) {
    if (next == _state) return true;
    return _allowedTransitions[_state]?.contains(next) == true;
  }

  void transitionTo(VerificationFlowState next) {
    if (!canTransitionTo(next)) {
      throw StateError(
        'Invalid verification transition: ${_state.name} -> ${next.name}',
      );
    }
    _state = next;
  }

  static const Map<VerificationFlowState, Set<VerificationFlowState>>
  _allowedTransitions = {
    VerificationFlowState.notStarted: {
      VerificationFlowState.capturingIdentity,
      VerificationFlowState.expired,
      VerificationFlowState.reverificationRequired,
    },
    VerificationFlowState.capturingIdentity: {
      VerificationFlowState.processingIdentity,
      VerificationFlowState.notStarted,
      VerificationFlowState.failed,
    },
    VerificationFlowState.processingIdentity: {
      VerificationFlowState.identityDataChecked,
      VerificationFlowState.identityRetryRequired,
      VerificationFlowState.failed,
    },
    VerificationFlowState.identityRetryRequired: {
      VerificationFlowState.capturingIdentity,
      VerificationFlowState.failed,
    },
    VerificationFlowState.identityDataChecked: {
      VerificationFlowState.capturingVehicle,
      VerificationFlowState.capturingIdentity,
      VerificationFlowState.reverificationRequired,
    },
    VerificationFlowState.capturingVehicle: {
      VerificationFlowState.processingVehicle,
      VerificationFlowState.identityDataChecked,
      VerificationFlowState.failed,
    },
    VerificationFlowState.processingVehicle: {
      VerificationFlowState.verified,
      VerificationFlowState.awaitingDeclaration,
      VerificationFlowState.vehicleRetryRequired,
      VerificationFlowState.failed,
    },
    VerificationFlowState.vehicleRetryRequired: {
      VerificationFlowState.capturingVehicle,
      VerificationFlowState.failed,
    },
    VerificationFlowState.awaitingDeclaration: {
      VerificationFlowState.declarationSigning,
      VerificationFlowState.capturingVehicle,
      VerificationFlowState.failed,
    },
    VerificationFlowState.declarationSigning: {
      VerificationFlowState.verified,
      VerificationFlowState.awaitingDeclaration,
      VerificationFlowState.failed,
    },
    VerificationFlowState.verified: {
      VerificationFlowState.expired,
      VerificationFlowState.reverificationRequired,
    },
    VerificationFlowState.expired: {
      VerificationFlowState.reverificationRequired,
    },
    VerificationFlowState.reverificationRequired: {
      VerificationFlowState.capturingIdentity,
    },
    VerificationFlowState.failed: {
      VerificationFlowState.capturingIdentity,
      VerificationFlowState.capturingVehicle,
      VerificationFlowState.notStarted,
    },
  };
}

class_name TechniqueLabels
extends RefCounted

const NAME_BY_TYPE := {
    TechniqueExecutor.TechniqueType.RAPPORT_BUILDING: "라포 형성",
    TechniqueExecutor.TechniqueType.INCONSISTENCY_POINT: "모순점 지적",
    TechniqueExecutor.TechniqueType.HIGH_PRESSURE: "강하게 밀어붙이기",
    TechniqueExecutor.TechniqueType.SILENCE: "침묵",
    TechniqueExecutor.TechniqueType.MINIMIZATION: "최소화",
    TechniqueExecutor.TechniqueType.MAXIMIZATION: "최대화",
    TechniqueExecutor.TechniqueType.FALSE_EVIDENCE: "허위 증거 제시",
    TechniqueExecutor.TechniqueType.COGNITIVE_LOAD: "인지 부하",
    TechniqueExecutor.TechniqueType.THIRD_PARTY_MENTION: "제3자 언급",
    TechniqueExecutor.TechniqueType.ROLE_REVERSAL: "역할 전환",
}

const NAME_BY_RESULT := {
    TechniqueExecutor.TechniqueResult.SUCCESS: "성공",
    TechniqueExecutor.TechniqueResult.NO_EFFECT: "효과 없음",
    TechniqueExecutor.TechniqueResult.BACKFIRE: "역효과",
    TechniqueExecutor.TechniqueResult.CRITICAL_FAIL: "치명적 실패",
}

const RECEPTION_BY_TYPE := {
    TechniqueExecutor.TechniqueType.RAPPORT_BUILDING: "당신의 말을 공감으로 받아들인 듯하다.",
    TechniqueExecutor.TechniqueType.INCONSISTENCY_POINT: "진술의 허점을 찔렸다고 느낀 듯하다.",
    TechniqueExecutor.TechniqueType.HIGH_PRESSURE: "당신의 말을 강한 압박으로 받아들인 듯하다.",
    TechniqueExecutor.TechniqueType.SILENCE: "당신의 침묵을 의식하는 듯하다.",
    TechniqueExecutor.TechniqueType.MINIMIZATION: "죄가 생각보다 가벼울 수 있다는 말로 받아들인 듯하다.",
    TechniqueExecutor.TechniqueType.MAXIMIZATION: "사태가 심각하다는 경고로 받아들인 듯하다.",
    TechniqueExecutor.TechniqueType.FALSE_EVIDENCE: "당신이 내민 증거가 진짜인지 가늠하는 듯하다.",
    TechniqueExecutor.TechniqueType.COGNITIVE_LOAD: "쏟아지는 질문에 생각을 정리하느라 애쓰는 듯하다.",
    TechniqueExecutor.TechniqueType.THIRD_PARTY_MENTION: "다른 사람 이야기에 신경이 쓰이는 듯하다.",
    TechniqueExecutor.TechniqueType.ROLE_REVERSAL: "입장을 바꿔 보라는 말로 받아들인 듯하다.",
}
const RECEPTION_NO_TECHNIQUE := "특별한 의도가 없는 질문으로 받아들인 듯하다."

const RESULT_NARRATION_BY_RESULT := {
    TechniqueExecutor.TechniqueResult.SUCCESS: "분명한 반응이 있다.",
    TechniqueExecutor.TechniqueResult.NO_EFFECT: "하지만 별다른 동요는 없다.",
    TechniqueExecutor.TechniqueResult.BACKFIRE: "오히려 역효과가 난 것 같다.",
    TechniqueExecutor.TechniqueResult.CRITICAL_FAIL: "완전히 역효과다. 상황이 나빠졌다.",
}

static func describe_turn(has_technique: bool, technique: TechniqueExecutor.TechniqueType,
        result: TechniqueExecutor.TechniqueResult) -> String:
    if not has_technique:
        return RECEPTION_NO_TECHNIQUE
    return "%s %s" % [RECEPTION_BY_TYPE[technique], RESULT_NARRATION_BY_RESULT[result]]

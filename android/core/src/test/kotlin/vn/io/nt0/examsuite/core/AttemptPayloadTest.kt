package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.attempt.AttemptPayloadException
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.core.session.SessionMode

/** Payload lần thi riêng của Android (Q11): JSON mẫu cố định, đọc lại, kiểm nhất quán như `AttemptRecord` bản macOS. */
class AttemptPayloadTest {
    private val golden = javaClass.getResource("/attempt-payload-v1.json")!!.readText()

    @Test
    fun `JSON mẫu cố định, khoá và cách ghi không đổi ngầm (đổi thì tăng payloadVersion)`() {
        assertEquals(golden, AttemptSamples.payload().encode())
    }

    @Test
    fun `đọc lại JSON mẫu ra đúng payload, seed giữ đủ 64 bit không dấu`() {
        val payload = AttemptPayload.decode(golden)
        assertEquals(AttemptSamples.payload(), payload)
        assertEquals(18_446_744_073_709_551_557uL, payload.options.seed)
        assertTrue(golden.contains("\"seed\":\"18446744073709551557\""))
    }

    @Test
    fun `chỉ lưu được phiên đã nộp, thiếu hay sai dạng dấu vân tay bị từ chối`() {
        val s = AttemptSamples.practice()
        val fps = QuestionFingerprint.fingerprints(s.exam)
        val first = s.paper.questionIds.first()
        assertThrows(AttemptPayloadException.MissingFingerprint::class.java) { AttemptPayload.from(s, fps - first) }
        assertThrows(AttemptPayloadException.InvalidFingerprint::class.java) { AttemptPayload.from(s, fps + (first to "ABC")) }
        val running = vn.io.nt0.examsuite.core.session.ExamSession.start(s.exam, s.paper, SessionMode.EXAM, null, "A", FakeClock())
        assertThrows(AttemptPayloadException.SessionNotSubmitted::class.java) { AttemptPayload.from(running, fps) }
    }

    @Test
    fun `payloadVersion kiểm trước mọi trường, mới hơn app thì UnsupportedVersion, nhỏ hơn 1 hay thiếu thì Malformed`() {
        assertEquals(AttemptPayloadException.UnsupportedVersion(2, 1), assertThrows(AttemptPayloadException.UnsupportedVersion::class.java) {
            AttemptPayload.decode("""{"payloadVersion":2,"cấu trúc":"mới"}""")
        })
        for (bad in listOf("""{"payloadVersion":0}""", """{"mode":"exam"}""", "không phải JSON", "[1]")) {
            assertThrows(AttemptPayloadException.Malformed::class.java, { AttemptPayload.decode(bad) }, bad)
        }
    }

    @Test
    fun `JSON sai kiểu, thiếu khoá, khoá lạ, mã lựa chọn lặp, seed không phải số thì Malformed`() {
        for ((old, new) in listOf(
            "\"mode\":\"practice\"" to "\"mode\":\"thi\"",
            "\"mode\":\"practice\"," to "",
            "\"payloadVersion\":1," to "\"payloadVersion\":1,\"lạ\":1,",
            "\"seed\":\"18446744073709551557\"" to "\"seed\":\"18446744073709551616\"",
            "\"optionOrder\":[\"C\",\"A\",\"B\"]" to "\"optionOrder\":[\"C\",\"A\",\"A\"]",
        )) {
            check(golden.contains(old)) { old }
            assertThrows(AttemptPayloadException.Malformed::class.java, { AttemptPayload.decode(golden.replace(old, new)) }, new)
        }
    }

    @Test
    fun `mâu thuẫn giữa đề đã tạo, đáp án, kết quả và dấu vân tay thì Inconsistent`() {
        val p = AttemptSamples.payload()
        val first = p.paper.questionIds.first()
        val cases = listOf(
            p.copy(timeLimitMinutes = 30),
            p.copy(mode = SessionMode.EXAM, timeLimitMinutes = 30),
            p.copy(checkedQuestionIds = p.checkedQuestionIds + p.paper.questionIds.last()),
            p.copy(answers = p.answers + (first to emptySet())),
            p.copy(answers = p.answers + (p.paper.questionIds[4] to AttemptSamples.letters("Z"))),
            p.copy(flagged = p.flagged + Build.id(5)),
            p.copy(fingerprints = p.fingerprints - first),
            p.copy(result = p.result.copy(correct = p.result.correct + 1)),
            p.copy(result = p.result.copy(passed = !p.result.passed)),
            p.copy(result = p.result.copy(outcomes = p.result.outcomes + (first to QuestionOutcome.UNANSWERED))),
            p.copy(result = p.result.copy(questionIds = p.result.questionIds.reversed())),
        )
        cases.forEachIndexed { i, bad ->
            assertTrue(bad.consistencyProblem() != null, "ca $i")
            assertThrows(AttemptPayloadException.Inconsistent::class.java, { AttemptPayload.decode(bad.encode()) }, "ca $i")
        }
        assertEquals(null, p.consistencyProblem())
    }

    @Test
    fun `phiên Thi lưu thời hạn, không có Kiểm tra đáp án, đọc lại được`() {
        val exam = AttemptSamples.exam
        val clock = FakeClock()
        val s = vn.io.nt0.examsuite.core.session.ExamSession.start(exam, vn.io.nt0.examsuite.core.composer.ExamComposer.compose(exam,
            vn.io.nt0.examsuite.core.composer.CompositionOptions(vn.io.nt0.examsuite.core.composer.QuestionSelection.Random(3), seed = 9uL)),
            SessionMode.EXAM, 20, "B", clock)
        s.openReview(); s.submit()
        val payload = AttemptSamples.payload(s)
        assertEquals(payload, AttemptPayload.decode(payload.encode()))
        assertEquals(20, payload.timeLimitMinutes)
    }
}

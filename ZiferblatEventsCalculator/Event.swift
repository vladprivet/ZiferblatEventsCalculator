//
//  tryAgain.swift
//
//
//  Created by Vladyslav Polishchuk on 02.08.25.
//

import Foundation

import Foundation

struct Event: Identifiable, Codable, Hashable {
    var id: UUID
    var eventName: String
    var curName: String
    var orgFee: Double
    var limit: Double?
    var paysOrg: Bool
    var curFeeOverride: Double? // используется, если paysOrg == false

    init(
        id: UUID = UUID(),
        eventName: String,
        curName: String = "lula",
        orgFee: Double,
        limit: Double? = nil,
        paysOrg: Bool = true,
        curFeeOverride: Double? = nil
    ) {
        self.id = id
        self.eventName = eventName
        self.curName = curName
        self.orgFee = orgFee
        self.limit = limit
        self.paysOrg = paysOrg
        self.curFeeOverride = curFeeOverride
    }
}

struct EventInstance: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var eventInstanceName: String
    var instanceCurName: String
    var numberOfPeople: Int
    var instanceMoney: Double
    var instanceOrgFee: Double
    var instanceCurFee: Double

    // Флаги (сохраняем для обратной совместимости)
    var orgPaid: Bool = false
    var curPaid: Bool = false

    // Новое — частичные выплаты:
    var orgPaidAmount: Double = 0
    var curPaidAmount: Double = 0

    // Удобные вычисляемые свойства
    var isOrgFullyPaid: Bool { orgPaidAmount >= instanceOrgFee - 0.005 }
    var isCurFullyPaid: Bool { curPaidAmount >= instanceCurFee - 0.005 }
}

import Foundation

func tryAgain(event: Event, money: Double, numOfPeople: Int, limit: Double = 0, date: Date = Date()) -> EventInstance {
    var curFee: Double = 0

    if !event.paysOrg {
        curFee = event.curFeeOverride ?? 0.05
    } else {
        switch event.orgFee {
        case 0.25:
            curFee = 0.05
        case 0.3:
            if money >= limit {
                curFee = 0.05
            }
        default:
            curFee = 0
        }
    }

    let forOrg = event.paysOrg ? money * event.orgFee : 0
    let forCur = money * curFee

    return EventInstance(
        date: date,
        eventInstanceName: event.eventName,
        instanceCurName: event.curName,
        numberOfPeople: numOfPeople,
        instanceMoney: money,
        instanceOrgFee: forOrg,
        instanceCurFee: forCur,
        orgPaid: false,
        curPaid: false,
        orgPaidAmount: 0,
        curPaidAmount: 0
    )
}

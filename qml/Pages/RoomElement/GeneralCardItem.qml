import QtQuick 2.15
import "../skin-bank.js" as SkinBank

/* Layout of general card:
 *      +--------+
 *kindom|wu  9999| <- hp
 *name -|s       |
 *      |q img   |
 *      |        |
 *      |        |
 *      +--------+
 * Inherit from CardItem to use common signal
 */

CardItem {
    property string kingdom: "qun"
    name: "caocao"
    // description: Sanguosha.getGeneralDescription(name)
    suit: ""
    number: 0
    footnote: ""
    card.source: SkinBank.GENERAL_DIR + name
    glow.color: "white" //Engine.kingdomColor[kingdom]
}
